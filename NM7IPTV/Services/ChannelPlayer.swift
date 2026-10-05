import AVFoundation
import Foundation
import MobileVLCKit
import UIKit

@MainActor
final class ChannelPlayer: NSObject, ObservableObject {
    enum Engine {
        case avPlayer
        case vlc
    }

    let player = AVPlayer()
    let vlcPlayer = VLCMediaPlayer()
    @Published private(set) var engine: Engine = .avPlayer
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var itemObservation: NSKeyValueObservation?
    private var playerObservation: NSKeyValueObservation?
    private var fallbackTask: Task<Void, Never>?
    private var currentChannel: Channel?
    private weak var vlcDrawable: UIView?

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        vlcPlayer.delegate = self
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self, self.engine == .avPlayer else { return }
                if player.timeControlStatus == .playing {
                    self.isLoading = false
                    self.fallbackTask?.cancel()
                } else if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    self.isLoading = true
                }
            }
        }
    }

    func attachVLCView(_ view: UIView) {
        vlcDrawable = view
        vlcPlayer.drawable = view
    }

    var isPlaying: Bool {
        engine == .avPlayer ? player.timeControlStatus == .playing : vlcPlayer.isPlaying
    }

    func togglePlayPause() {
        if engine == .avPlayer {
            if player.timeControlStatus == .playing { player.pause() } else { player.play() }
        } else {
            if vlcPlayer.isPlaying { vlcPlayer.pause() } else { vlcPlayer.play() }
        }
    }

    func play(_ channel: Channel) {
        stopPlayback()
        currentChannel = channel
        errorMessage = nil
        isLoading = true
        engine = .avPlayer

        var headers = channel.httpHeaders
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            headers["User-Agent"] = "NM7-IPTV-iOS/0.3.0"
        }

        let asset = AVURLAsset(
            url: channel.streamURL,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.engine == .avPlayer else { return }
                switch item.status {
                case .readyToPlay:
                    break
                case .failed:
                    self.startVLCFallback(for: channel)
                default:
                    break
                }
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()

        fallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, self.engine == .avPlayer,
                  self.player.timeControlStatus != .playing else { return }
            self.startVLCFallback(for: channel)
        }
    }

    private func startVLCFallback(for channel: Channel) {
        guard currentChannel?.id == channel.id, engine == .avPlayer else { return }
        fallbackTask?.cancel()
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)

        let media = VLCMedia(url: channel.streamURL)
        var options: [String: Any] = [
            "network-caching": 1800,
            "clock-jitter": 0,
            "clock-synchro": 0
        ]
        for (name, value) in channel.httpHeaders {
            switch name.lowercased() {
            case "user-agent":
                options["http-user-agent"] = value
            case "referer":
                options["http-referrer"] = value
            case "cookie":
                options["http-cookie"] = value
            default:
                options["http-header"] = "\(name): \(value)"
            }
        }
        if options["http-user-agent"] == nil {
            options["http-user-agent"] = "NM7-IPTV-iOS/0.3.0"
        }
        media.addOptions(options)
        engine = .vlc
        isLoading = true
        vlcPlayer.drawable = vlcDrawable
        vlcPlayer.media = media
        vlcPlayer.play()
    }

    func showError(_ message: String) { errorMessage = message }

    func stop() {
        currentChannel = nil
        stopPlayback()
        isLoading = false
        errorMessage = nil
    }

    private func stopPlayback() {
        fallbackTask?.cancel()
        fallbackTask = nil
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        vlcPlayer.stop()
    }
}

extension ChannelPlayer: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification!) {
        Task { @MainActor [weak self] in
            guard let self, self.engine == .vlc else { return }
            switch self.vlcPlayer.state {
            case .playing:
                self.isLoading = false
                self.errorMessage = nil
            case .buffering, .opening:
                self.isLoading = true
            case .error:
                self.isLoading = false
                self.errorMessage = "AVPlayer và VLC đều không mở được luồng này. Kênh có thể đang ngoại tuyến hoặc dùng DRM."
            case .ended, .stopped:
                self.isLoading = false
            default:
                break
            }
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification!) {}
}
