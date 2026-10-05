import Foundation

@MainActor
final class SourceStore: ObservableObject {
    static let defaultID = "nm7-default-tv"
    static let sportsID = "nm7-sports"

    private static let defaultURL = URL(string: "https://phuongnm7-playlist.phuongnm7-iptv.workers.dev/")!
    private static let sportsURL = URL(string: "https://thethaonm7.phuongnm7-iptv.workers.dev/playlist.m3u")!
    private static let sourcesKey = "nm7.ios.sources.v2"
    private static let activeKey = "nm7.ios.activeSource.v2"

    @Published private(set) var customSources: [PlaylistSource] = []
    @Published private(set) var activeSourceID: String = defaultID

    var defaultSource: PlaylistSource {
        PlaylistSource(id: Self.defaultID, name: "Truyền hình", url: Self.defaultURL, isBuiltIn: true)
    }

    var sportsSource: PlaylistSource {
        PlaylistSource(id: Self.sportsID, name: "Thể thao", url: Self.sportsURL, isBuiltIn: true)
    }

    var builtInSources: [PlaylistSource] { [defaultSource, sportsSource] }
    var allSources: [PlaylistSource] { builtInSources + customSources }

    var activeSource: PlaylistSource {
        allSources.first(where: { $0.id == activeSourceID }) ?? defaultSource
    }

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.sourcesKey),
           let decoded = try? JSONDecoder().decode([PlaylistSource].self, from: data) {
            customSources = decoded.filter { !$0.isBuiltIn }
        }
        let saved = defaults.string(forKey: Self.activeKey) ?? Self.defaultID
        activeSourceID = allSources.contains(where: { $0.id == saved }) ? saved : Self.defaultID
        persist(defaults)
    }

    func add(name: String, urlText: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw SourceError.invalidURL
        }
        guard !allSources.contains(where: { $0.url == url }) else { throw SourceError.duplicate }

        customSources.insert(
            PlaylistSource(id: UUID().uuidString,
                           name: cleanName.isEmpty ? (url.host ?? "Nguồn IPTV") : cleanName,
                           url: url,
                           isBuiltIn: false),
            at: 0
        )
        persist()
    }

    func select(_ source: PlaylistSource) {
        activeSourceID = source.id
        persist()
    }

    func remove(at offsets: IndexSet) {
        customSources.remove(atOffsets: offsets)
        if !allSources.contains(where: { $0.id == activeSourceID }) {
            activeSourceID = Self.defaultID
        }
        persist()
    }

    private func persist(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(customSources) {
            defaults.set(data, forKey: Self.sourcesKey)
        }
        defaults.set(activeSourceID, forKey: Self.activeKey)
    }

    enum SourceError: LocalizedError {
        case invalidURL, duplicate
        var errorDescription: String? {
            self == .invalidURL ? "URL nguồn không hợp lệ." : "Nguồn này đã tồn tại."
        }
    }
}
