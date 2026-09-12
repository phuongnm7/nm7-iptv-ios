import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var recentIDs: [String]
    private let defaults: UserDefaults
    private let favoritesKey = "nm7.ios.favorites"
    private let recentKey = "nm7.ios.recent"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoriteIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        recentIDs = defaults.stringArray(forKey: recentKey) ?? []
    }

    func toggleFavorite(_ channel: Channel) {
        if favoriteIDs.contains(channel.id) { favoriteIDs.remove(channel.id) }
        else { favoriteIDs.insert(channel.id) }
        defaults.set(Array(favoriteIDs), forKey: favoritesKey)
    }

    func addRecent(_ channel: Channel) {
        recentIDs.removeAll { $0 == channel.id }
        recentIDs.insert(channel.id, at: 0)
        recentIDs = Array(recentIDs.prefix(50))
        defaults.set(recentIDs, forKey: recentKey)
    }
}
