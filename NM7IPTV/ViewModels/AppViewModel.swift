import Foundation
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case home = "Trang chính"
        case television = "Truyền hình"
        case sports = "Thể thao"
        case all = "Tất cả các kênh"
        case favorites = "Yêu thích"
        case recent = "Gần đây"
        case sources = "Nguồn IPTV"
        case settings = "Tùy chọn ứng dụng"
        var id: String { rawValue }
    }

    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedGroup = "Tất cả"
    @Published var section: Section = .home
    @Published var selectedChannel: Channel?
    @Published private(set) var epgURL: URL?

    let sourceStore = SourceStore()
    let libraryStore = LibraryStore()
    private let service = PlaylistService()

    init() { Task { await start() } }

    var groups: [String] {
        var seen = Set<String>()
        let discovered = channels.compactMap { channel -> (String, Int)? in
            let group = channel.group
            guard seen.insert(group).inserted else { return nil }
            return (group, channels.firstIndex(where: { $0.group == group }) ?? Int.max)
        }

        func priority(_ group: String) -> Int {
            let value = group.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if value == "vtv" { return 0 }
            if value == "vtvcab" { return 1 }
            if value == "thể thao" || value == "the thao" { return 2 }
            if value == "sctv" { return 3 }
            if value == "sự kiện fpt play" || value == "sự kiện fpt" { return 4 }
            if value == "vtv dự phòng" { return 5 }
            if value == "giờ vàng tv" { return 6 }
            if value.contains("gà vàng 33") || value.contains("ga vang 33") { return 7 }
            return 100
        }

        return discovered
            .sorted {
                let p0 = priority($0.0)
                let p1 = priority($1.0)
                return p0 == p1 ? $0.1 < $1.1 : p0 < p1
            }
            .map(\.0)
    }

    var visibleChannels: [Channel] {
        var result = channels

        if section == .favorites {
            result = result.filter { libraryStore.favoriteIDs.contains($0.id) }
        } else if section == .recent {
            let order = Dictionary(uniqueKeysWithValues: libraryStore.recentIDs.enumerated().map { ($1, $0) })
            result = result.filter { order[$0.id] != nil }
                .sorted { order[$0.id, default: 999] < order[$1.id, default: 999] }
        }

        if selectedGroup != "Tất cả" {
            result = result.filter { $0.group == selectedGroup }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.group.localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    func start() async {
        if let cached = await service.cached() {
            channels = cached.channels
            epgURL = cached.epgURL
        }
        await reload()
    }

    func reload() async {
        isLoading = channels.isEmpty
        errorMessage = nil

        do {
            let loaded = try await service.fetch(from: sourceStore.activeSource)
            channels = loaded.channels
            epgURL = loaded.epgURL
            if selectedGroup != "Tất cả" && !groups.contains(selectedGroup) {
                selectedGroup = "Tất cả"
            }
        } catch {
            if channels.isEmpty {
                errorMessage = "Không tải được playlist: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    func selectSection(_ next: Section) async {
        section = next
        searchText = ""
        selectedGroup = "Tất cả"

        switch next {
        case .television:
            if sourceStore.activeSourceID != SourceStore.defaultID {
                sourceStore.select(sourceStore.defaultSource)
                await reload()
            }
        case .sports:
            if sourceStore.activeSourceID != SourceStore.sportsID {
                sourceStore.select(sourceStore.sportsSource)
                await reload()
            }
        default:
            break
        }
    }

    func selectSource(_ source: PlaylistSource) async {
        sourceStore.select(source)
        section = source.id == SourceStore.sportsID ? .sports : .television
        selectedGroup = "Tất cả"
        await reload()
    }

    func play(_ channel: Channel) {
        libraryStore.addRecent(channel)
        selectedChannel = channel
    }

    func toggleFavorite(_ channel: Channel) {
        libraryStore.toggleFavorite(channel)
        objectWillChange.send()
    }

    func bestVoiceMatch(for transcript: String) -> Channel? {
        VoiceChannelMatcher.bestMatch(for: transcript, channels: channels)
    }

    func openVoiceChannel(_ transcript: String) {
        searchText = transcript
        if let channel = bestVoiceMatch(for: transcript) {
            play(channel)
        } else {
            errorMessage = "Không tìm thấy kênh phù hợp với “\(transcript)”."
        }
    }

    func openYouTube() {
        let appURL = URL(string: "youtube://")!
        let webURL = URL(string: "https://www.youtube.com")!
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}