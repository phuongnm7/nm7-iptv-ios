import AVFoundation
import Foundation
import MobileVLCKit
import UIKit

@MainActor
final class ChannelPlayer: NSObject, ObservableObject {
    enum Engine: Equatable { case avPlayer, vlc }

    let player = AVPlayer()
    let vlcPlayer = VLCMediaPlayer()

    @Published private(set) var engine: Engine = .avPlayer
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage = ""
    @Published var errorMessage: String?

    private var itemObservation: NSKeyValueObservation?
    private var playerObservation: NSKeyValueObservation?
    private var stallObserver: NSObjectProtocol?
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
                switch player.timeControlStatus {
                case .playing:
                    self.isLoading = false
                    self.statusMessage = ""
                    self.fallbackTask?.cancel()
                case .waitingToPlayAtSpecifiedRate:
                    self.isLoading = true
                    self.statusMessage = "Đang ổn định bộ đệm…"
                case .paused:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    func attachVLCView(_ view: UIView) {
        vlcDrawable = view
        vlcPlayer.drawable = view
    }

    func play(_ channel: Channel) {
        stopPlayback()
        currentChannel = channel
        errorMessage = nil
        statusMessage = "Đang kết nối…"
        isLoading = true
        engine = .avPlayer
        configureAudioSession()

        // AVPlayer is the preferred native iOS engine for HLS/MP4.
        // DASH/DRM is reported honestly instead of trying to bypass protection.
        if channel.isDASH {
            showError("Nguồn DASH/DRM này không có đường phát native iOS được cấu hình. Hãy dùng nguồn HLS/FairPlay tương thích Apple.")
            return
        }

        var headers = channel.httpHeaders
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            headers["User-Agent"] = "NM7-TV-iOS/1.0.69"
        }

        let asset = AVURLAsset(
            url: channel.streamURL,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8

        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.engine == .avPlayer,
                      self.currentChannel?.id == channel.id else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.statusMessage = ""
                case .failed:
                    self.startVLCFallback(for: channel)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.engine == .avPlayer,
                      self.currentChannel?.id == channel.id else { return }

                self.isLoading = true
                self.statusMessage = "Nguồn phát đang bị gián đoạn…"
                self.fallbackTask?.cancel()
                self.fallbackTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(7))
                    guard !Task.isCancelled, let self,
                          self.engine == .avPlayer,
                          self.currentChannel?.id == channel.id,
                          self.player.timeControlStatus != .playing else { return }
                    self.startVLCFallback(for: channel)
                }
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()
    }

    func showError(_ message: String) {
        errorMessage = message
        statusMessage = message
        isLoading = false
    }

    func stop() {
        currentChannel = nil
        stopPlayback()
        isLoading = false
        statusMessage = ""
        errorMessage = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startVLCFallback(for channel: Channel) {
        guard currentChannel?.id == channel.id else { return }

        fallbackTask?.cancel()
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let observer = stallObserver {
            NotificationCenter.default.removeObserver(observer)
            stallObserver = nil
        }

        var options: [String: Any] = [
            "network-caching": 1200,
            "clock-jitter": 0,
            "clock-synchro": 0,
            "http-reconnect": 1
        ]

        for (name, value) in channel.httpHeaders {
            switch name.lowercased() {
            case "user-agent": options["http-user-agent"] = value
            case "referer": options["http-referrer"] = value
            case "cookie": options["http-cookie"] = value
            default: break
            }
        }
        if options["http-user-agent"] == nil {
            options["http-user-agent"] = "NM7-TV-iOS/1.0.69"
        }

        let media = VLCMedia(url: channel.streamURL)
        media.addOptions(options)
        engine = .vlc
        isLoading = true
        statusMessage = "Đang chuyển sang VLC…"
        vlcPlayer.drawable = vlcDrawable
        vlcPlayer.media = media
        vlcPlayer.play()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback,
                                    options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {}
    }

    private func stopPlayback() {
        fallbackTask?.cancel()
        fallbackTask = nil
        itemObservation = nil
        if let observer = stallObserver {
            NotificationCenter.default.removeObserver(observer)
            stallObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        vlcPlayer.stop()
    }

    deinit {
        if let observer = stallObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        playerObservation?.invalidate()
    }
}

extension ChannelPlayer: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification!) {
        Task { @MainActor [weak self] in
            guard let self, self.engine == .vlc else { return }
            switch self.vlcPlayer.state {
            case .playing:
                self.isLoading = false
                self.statusMessage = ""
                self.errorMessage = nil
            case .buffering, .opening:
                self.isLoading = true
                self.statusMessage = "Đang ổn định luồng…"
            case .error:
                self.isLoading = false
                self.statusMessage = "VLC không mở được luồng này."
                self.errorMessage = "AVPlayer và VLC đều không mở được luồng. Nguồn có thể yêu cầu DRM/FairPlay hoặc đang ngoại tuyến."
            case .ended, .stopped:
                self.isLoading = false
            default:
                break
            }
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification!) {}
}
