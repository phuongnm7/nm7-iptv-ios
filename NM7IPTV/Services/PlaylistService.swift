import Foundation

actor PlaylistService {
    struct LoadedPlaylist {
        let channels: [Channel]
        let epgURL: URL?
    }

    enum PlaylistError: LocalizedError {
        case empty
        var errorDescription: String? { "Playlist không có kênh hợp lệ." }
    }

    private let cacheURL: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = base.appendingPathComponent("nm7-1.0.72-channels-v4.json")
    }

    func cached() -> LoadedPlaylist? {
        guard let data = try? Data(contentsOf: cacheURL),
              let value = try? JSONDecoder().decode(CachePayload.self, from: data) else { return nil }

        return LoadedPlaylist(
            channels: value.channels,
            epgURL: value.epgURL.flatMap(URL.init(string:))
        )
    }

    func fetch(from source: PlaylistSource) async throws -> LoadedPlaylist {
        let data: Data
        if source.url.isFileURL {
            data = try Data(contentsOf: source.url)
        } else {
            var request = URLRequest(
                url: source.url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            request.setValue("NM7-TV-iOS/1.0.70", forHTTPHeaderField: "User-Agent")
            request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
            request.setValue("application/vnd.apple.mpegurl,application/x-mpegURL,text/plain,*/*", forHTTPHeaderField: "Accept")

            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }
            data = responseData
        }

        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""

        let parsed = M3UParser.parse(text, baseURL: source.url)
        guard !parsed.channels.isEmpty else { throw PlaylistError.empty }

        var channels = parsed.channels

        // The public web playlist and the current merge worker do not always
        // expose the VTV "Dự phòng" entries. Pull the repository's vmttv source
        // as a secondary source so the iOS app does not lose this group.
        if source.id == SourceStore.defaultID,
           let backupURL = URL(string: "https://raw.githubusercontent.com/phuongnm7/Iptv-phuongnm7/main/vmttv"),
           let backupText = try? await fetchText(url: backupURL) {
            let backup = M3UParser.parse(backupText, baseURL: backupURL)
            let vtvPrimary = backup.channels.filter {
                let group = $0.group
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let name = $0.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return group == "vtv" &&
                    name.hasPrefix("vtv") &&
                    !$0.isDASH &&
                    !$0.isLikelyDRM
            }

            let vtvBackup = backup.channels.filter {
                let group = $0.group
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let name = $0.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return (group.contains("dự phòng") || group.contains("du phong")) &&
                    name.hasPrefix("vtv")
            }

            // Bring in both the known-good VTV HLS primary entries and their
            // backup records, then normalize once so backup mapping can resolve
            // against a guaranteed non-DRM primary.
            channels.append(contentsOf: vtvPrimary)
            channels.append(contentsOf: vtvBackup)
            channels = M3UParser.normalizeForIOS(channels)

            var seen = Set<String>()
            channels = channels.filter { seen.insert($0.id).inserted }
        }

        let result = LoadedPlaylist(
            channels: channels,
            epgURL: parsed.epgURL
        )

        let payload = CachePayload(
            channels: result.channels,
            epgURL: result.epgURL?.absoluteString
        )

        if let encoded = try? JSONEncoder().encode(payload) {
            try? encoded.write(to: cacheURL, options: .atomic)
        }

        return LoadedPlaylist(channels: result.channels, epgURL: result.epgURL)
    }

    private func fetchText(url: URL) async throws -> String {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.setValue("NM7-TV-iOS/1.0.70", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/vnd.apple.mpegurl,application/x-mpegURL,text/plain,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    private struct CachePayload: Codable {
        let channels: [Channel]
        let epgURL: String?
    }
}
