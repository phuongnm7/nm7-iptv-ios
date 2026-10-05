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
        cacheURL = base.appendingPathComponent("nm7-1.0.69-channels.json")
    }

    func cached() -> LoadedPlaylist? {
        guard let data = try? Data(contentsOf: cacheURL),
              let value = try? JSONDecoder().decode(CachePayload.self, from: data) else {
            return nil
        }
        return LoadedPlaylist(channels: value.channels, epgURL: value.epgURL.flatMap(URL.init(string:)))
    }

    func fetch(from source: PlaylistSource) async throws -> LoadedPlaylist {
        var request = URLRequest(url: source.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("NM7-TV-iOS/1.0.69", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/vnd.apple.mpegurl,application/x-mpegURL,text/plain,*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let result = M3UParser.parse(text)
        guard !result.channels.isEmpty else { throw PlaylistError.empty }
        let payload = CachePayload(channels: result.channels, epgURL: result.epgURL?.absoluteString)
        if let encoded = try? JSONEncoder().encode(payload) {
            try? encoded.write(to: cacheURL, options: .atomic)
        }
        return LoadedPlaylist(channels: result.channels, epgURL: result.epgURL)
    }

    private struct CachePayload: Codable {
        let channels: [Channel]
        let epgURL: String?
    }
}
