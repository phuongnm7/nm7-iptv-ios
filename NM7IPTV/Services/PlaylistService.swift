import Foundation

actor PlaylistService {
    private let cacheURL: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = base.appendingPathComponent("nm7-channels-cache.json")
    }

    func cachedChannels() -> [Channel] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([Channel].self, from: data)) ?? []
    }

    func fetch(from source: PlaylistSource) async throws -> [Channel] {
        var request = URLRequest(url: source.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("NM7-IPTV-iOS/0.1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        let channels = M3UParser.parse(text)
        guard !channels.isEmpty else { throw PlaylistError.empty }
        if let encoded = try? JSONEncoder().encode(channels) {
            try? encoded.write(to: cacheURL, options: .atomic)
        }
        return channels
    }

    enum PlaylistError: LocalizedError {
        case empty
        var errorDescription: String? { "Playlist không có kênh hợp lệ." }
    }
}
