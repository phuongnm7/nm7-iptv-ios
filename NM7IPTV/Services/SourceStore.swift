import Foundation

@MainActor
final class SourceStore: ObservableObject {
    static let defaultID = "nm7-default"
    private static let defaultURL = URL(string: "https://phuongnm7-playlist.phuongnm7-iptv.workers.dev/")!
    private static let sourcesKey = "nm7.ios.customSources"
    private static let activeKey = "nm7.ios.activeSource"

    @Published private(set) var customSources: [PlaylistSource] = []
    @Published private(set) var activeSourceID: String = defaultID

    var defaultSource: PlaylistSource {
        PlaylistSource(id: Self.defaultID, name: "NM7 IPTV", url: Self.defaultURL, isBuiltIn: true)
    }

    var activeSource: PlaylistSource {
        if activeSourceID == Self.defaultID { return defaultSource }
        return customSources.first(where: { $0.id == activeSourceID }) ?? defaultSource
    }

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.sourcesKey),
           let decoded = try? JSONDecoder().decode([PlaylistSource].self, from: data) {
            customSources = decoded.filter { !$0.isBuiltIn && $0.url != Self.defaultURL }
        }
        let saved = defaults.string(forKey: Self.activeKey) ?? Self.defaultID
        activeSourceID = customSources.contains(where: { $0.id == saved }) ? saved : Self.defaultID
        persist(defaults)
    }

    func add(name: String, urlText: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw SourceError.invalidURL
        }
        guard url != Self.defaultURL else { throw SourceError.duplicate }
        guard !customSources.contains(where: { $0.url == url }) else { throw SourceError.duplicate }
        customSources.append(PlaylistSource(
            id: UUID().uuidString,
            name: cleanName.isEmpty ? (url.host ?? "Nguồn IPTV") : cleanName,
            url: url,
            isBuiltIn: false
        ))
        persist()
    }

    func select(_ source: PlaylistSource) {
        activeSourceID = source.isBuiltIn ? Self.defaultID : source.id
        persist()
    }

    func remove(at offsets: IndexSet) {
        let removedActive = offsets.contains { customSources[$0].id == activeSourceID }
        customSources.remove(atOffsets: offsets)
        if removedActive { activeSourceID = Self.defaultID }
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
            self == .invalidURL ? "URL nguồn không hợp lệ." : "Nguồn này đã tồn tại hoặc là nguồn mặc định."
        }
    }
}
