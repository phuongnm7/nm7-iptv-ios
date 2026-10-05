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
    private var fairPlayLoader: FairPlayKeyLoader?

    var isPlaying: Bool {
        engine == .avPlayer ? player.timeControlStatus == .playing : vlcPlayer.isPlaying
    }

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        vlcPlayer.delegate = self

        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    func attachVLCView(_ view: UIView) {
        vlcDrawable = view
        vlcPlayer.drawable = view
    }

    func togglePlayPause() {
        if engine == .avPlayer {
            if player.timeControlStatus == .playing { player.pause() } else { player.play() }
        } else {
            if vlcPlayer.isPlaying { vlcPlayer.pause() } else { vlcPlayer.play() }
        }
        objectWillChange.send()
    }

    func play(_ channel: Channel) {
        stopPlayback()
        currentChannel = channel
        errorMessage = nil
        statusMessage = "Đang kết nối…"
        isLoading = true
        engine = .avPlayer
        configureAudioSession()

        let drm = DRMInfo.from(options: channel.options)

        if drm.hasDRM && !drm.isNativeFairPlay {
            showError("Nguồn này dùng \(drm.system.description). iPhone/iPad không thể phát Widevine, PlayReady hoặc ClearKey Android native. Cần nguồn HLS + FairPlay của nhà cung cấp.")
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

        if drm.isNativeFairPlay {
            guard let certificateURL = drm.certificateURL, let licenseURL = drm.licenseURL else {
                showError("Kênh có FairPlay nhưng thiếu certificate URL hoặc license URL.")
                return
            }

            let licenseHeaders = drm.licenseHeaders.merging(channel.httpHeaders) { license, _ in license }
            let loader = FairPlayKeyLoader(
                certificateURL: certificateURL,
                licenseURL: licenseURL,
                headers: licenseHeaders
            )
            fairPlayLoader = loader

            let queue = DispatchQueue(label: "vn.phuongnm7.nm7iptv.fairplay.asset")
            asset.resourceLoader.setDelegate(loader, queue: queue)
        }

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8

        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.currentChannel?.id == channel.id else { return }

                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.statusMessage = ""
                    self.objectWillChange.send()

                case .failed:
                    let currentDRM = DRMInfo.from(options: channel.options)
                    if currentDRM.hasDRM {
                        self.showError("iOS không mở được phiên FairPlay/DRM của kênh. Kiểm tra certificate, license và quyền phát của nhà cung cấp.")
                    } else {
                        self.startVLCFallback(for: channel)
                    }

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
                guard let self, self.currentChannel?.id == channel.id else { return }
                self.isLoading = true
                self.statusMessage = "Nguồn phát đang bị gián đoạn…"

                guard !DRMInfo.from(options: channel.options).hasDRM else { return }

                self.fallbackTask?.cancel()
                self.fallbackTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(7))
                    guard !Task.isCancelled,
                          let self,
                          self.currentChannel?.id == channel.id,
                          self.player.timeControlStatus != .playing else { return }
                    self.startVLCFallback(for: channel)
                }
            }
        )

        player.replaceCurrentItem(with: item)
        player.play()
        objectWillChange.send()
    }

    func stop() {
        currentChannel = nil
        stopPlayback()
        isLoading = false
        statusMessage = ""
        errorMessage = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func showError(_ message: String) {
        errorMessage = message
        statusMessage = message
        isLoading = false
        objectWillChange.send()
    }

    private func startVLCFallback(for channel: Channel) {
        guard currentChannel?.id == channel.id else { return }
        guard !DRMInfo.from(options: channel.options).hasDRM else {
            showError("Không thể dùng VLC để bỏ qua DRM. Hãy dùng nguồn HLS/FairPlay tương thích iOS.")
            return
        }

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
        objectWillChange.send()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
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
        fairPlayLoader = nil
    }

    deinit {
        if let observer = stallObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        playerObservation?.invalidate()
    }
}

extension DRMInfo.System {
    var description: String {
        switch self {
        case .none: return "không DRM"
        case .fairPlay: return "FairPlay"
        case .widevine: return "Widevine"
        case .playReady: return "PlayReady"
        case .clearKey: return "ClearKey"
        case .unknown: return "DRM không xác định"
        }
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
            self.objectWillChange.send()
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification!) {}
}