import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Tất cả"
        case favorites = "Yêu thích"
        case recent = "Gần đây"
        var id: String { rawValue }
    }

    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedGroup = "Tất cả"
    @Published var filter: Filter = .all
    @Published var selectedChannel: Channel?

    let sourceStore = SourceStore()
    let libraryStore = LibraryStore()
    private let service = PlaylistService()

    init() {
        Task { await start() }
    }

    var groups: [String] {
        ["Tất cả"] + Array(Set(channels.map(\.group))).sorted()
    }

    var visibleChannels: [Channel] {
        var result = channels
        if selectedGroup != "Tất cả" { result = result.filter { $0.group == selectedGroup } }
        switch filter {
        case .all: break
        case .favorites: result = result.filter { libraryStore.favoriteIDs.contains($0.id) }
        case .recent:
            let order = Dictionary(uniqueKeysWithValues: libraryStore.recentIDs.enumerated().map { ($1, $0) })
            result = result.filter { order[$0.id] != nil }.sorted { order[$0.id, default: 999] < order[$1.id, default: 999] }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    func start() async {
        let cached = await service.cachedChannels()
        if !cached.isEmpty { channels = cached }
        await reload()
    }

    func reload() async {
        isLoading = channels.isEmpty
        errorMessage = nil
        do {
            channels = try await service.fetch(from: sourceStore.activeSource)
            if !groups.contains(selectedGroup) { selectedGroup = "Tất cả" }
        } catch {
            errorMessage = "Không tải được playlist: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func selectSource(_ source: PlaylistSource) async {
        sourceStore.select(source)
        selectedGroup = "Tất cả"
        await reload()
    }

    func play(_ channel: Channel) {
        libraryStore.addRecent(channel)
        selectedChannel = channel
    }

    func bestVoiceMatch(for transcript: String, in candidates: [Channel]? = nil) -> Channel? {
        VoiceChannelMatcher.bestMatch(for: transcript, channels: candidates ?? channels)
    }

    func openVoiceChannel(_ transcript: String) {
        searchText = transcript
        if let channel = bestVoiceMatch(for: transcript) {
            play(channel)
        } else {
            errorMessage = "Không tìm thấy kênh phù hợp với “\(transcript)”."
        }
    }

    func toggleFavorite(_ channel: Channel) {
        libraryStore.toggleFavorite(channel)
        objectWillChange.send()
    }
}
