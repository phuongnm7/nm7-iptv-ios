import AVFoundation
import Foundation

@MainActor
final class ChannelPlayer: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var itemObservation: NSKeyValueObservation?
    private var playerObservation: NSKeyValueObservation?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                if player.timeControlStatus == .playing { self.isLoading = false }
                else if player.timeControlStatus == .waitingToPlayAtSpecifiedRate { self.isLoading = true }
            }
        }
    }

    func play(_ channel: Channel) {
        errorMessage = nil
        isLoading = true
        var headers = channel.httpHeaders
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            headers["User-Agent"] = "NM7-IPTV-iOS/0.2.2"
        }
        let asset = AVURLAsset(
            url: channel.streamURL,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 12
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                case .failed:
                    self.isLoading = false
                    let detail = (item.error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                    self.errorMessage = detail ?? item.error?.localizedDescription ?? "Luồng phát không khả dụng."
                default:
                    break
                }
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func showError(_ message: String) { errorMessage = message }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObservation = nil
        isLoading = false
    }
}
