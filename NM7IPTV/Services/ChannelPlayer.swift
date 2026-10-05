import AVFoundation
import Foundation
import MobileVLCKit
import UIKit

@MainActor
final class ChannelPlayer: NSObject, ObservableObject {
    enum Engine { case avPlayer, dashClearKey, vlc }

    let player = AVPlayer()
    let vlcPlayer = VLCMediaPlayer()
    @Published private(set) var engine: Engine = .avPlayer
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var activeAVPlayer: AVPlayer {
        engine == .dashClearKey ? (dashPlayer?.avPlayer ?? player) : player
    }

    private var itemObservation: NSKeyValueObservation?
    private var playerObservation: NSKeyValueObservation?
    private var dashItemObservation: NSKeyValueObservation?
    private var fallbackTask: Task<Void, Never>?
    private var currentChannel: Channel?
    private weak var vlcDrawable: UIView?
    private var fairPlayLoader: FairPlayKeyLoader?
    private var dashPlayer: UPlayer?
    private var dashBridge: DashPlayerBridge?
    private var clearKeySession: AVContentKeySession?
    private var clearKeyDelegate: ClearKeyContentKeySession?
    private var cencProcessor: CENCResourceProcessor?

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        vlcPlayer.delegate = self
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
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
        engine == .vlc ? vlcPlayer.isPlaying : activeAVPlayer.timeControlStatus == .playing
    }

    func togglePlayPause() {
        if engine == .vlc {
            vlcPlayer.isPlaying ? vlcPlayer.pause() : vlcPlayer.play()
        } else {
            activeAVPlayer.timeControlStatus == .playing ? activeAVPlayer.pause() : activeAVPlayer.play()
        }
    }

    func play(_ channel: Channel) {
        stopPlayback()
        currentChannel = channel
        errorMessage = nil
        isLoading = true

        let drm = DRMInfo.from(options: channel.options)
        var headers = channel.httpHeaders
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            headers["User-Agent"] = "NM7-TV-iOS/1.0.69"
        }

        // DASH is handled by the native CENC/CBCS resource processor only for
        // unencrypted or ClearKey streams. Widevine/PlayReady still require
        // a device CDM that is not part of this native pipeline.
        if channel.isDASH {
            if drm.system == .widevine || drm.system == .playReady || drm.system == .unknown {
                showError("Kênh DASH đang dùng Widevine/PlayReady. iOS 1.0.70 chỉ xử lý DASH không mã hóa hoặc ClearKey.")
                return
            }
            startDASH(channel: channel, drm: drm)
            return
        }

        if drm.system == .widevine || drm.system == .playReady || drm.system == .unknown {
            showError("Nguồn dùng DRM không được iOS engine hỗ trợ trực tiếp. Chỉ FairPlay hoặc ClearKey được xử lý khi playlist cung cấp đầy đủ thông tin.")
            return
        }

        if drm.system == .clearKey {
            startNativeClearKey(channel: channel, headers: headers)
            return
        }

        if drm.isNativeFairPlay {
            startFairPlay(channel: channel, drm: drm, headers: headers)
            return
        }

        startAVPlayer(channel: channel, headers: headers)
    }

    private func startDASH(channel: Channel, drm: DRMInfo) {
        var headers = channel.httpHeaders
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            headers["User-Agent"] = "NM7-TV-iOS/1.0.69"
        }

        let dash = UPlayer()
        dash.requestHeaders = headers
        let processor = CENCResourceProcessor(drm: drm, headers: headers)
        cencProcessor = processor
        dash.mediaResourceProcessor = processor
        let queue = UPlayerAssetProcessorsQueue()
        queue.add(processor: UPlayerMetadataDownloader(id: "metadata"))
        queue.add(processor: UPlayerMPDParser(id: "mpd-parser"))
        queue.add(processor: UPlayerSegmentBaseHLSGenerator(id: "segment-base-hls"))
        queue.add(processor: UPlayerMPDToMP4Resolver(id: "mp4-resolver"))
        queue.add(processor: UPlayerHLSGenerator(id: "hls-generator"))
        dash.assetProcessorsQueue = queue

        let bridge = DashPlayerBridge(owner: self)
        dashBridge = bridge
        dash.delegate = bridge
        dashPlayer = dash

        engine = .dashClearKey
        dash.play(url: channel.streamURL)
    }

    private func startNativeClearKey(channel: Channel, headers: [String: String]) {
        let asset = AVURLAsset(url: channel.streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let delegate = ClearKeyContentKeySession(drm: DRMInfo.from(options: channel.options), headers: headers) { [weak self] message in
            Task { @MainActor in self?.showError(message) }
        }
        clearKeyDelegate = delegate
        let session = AVContentKeySession(keySystem: .clearKey)
        session.setDelegate(delegate, queue: DispatchQueue(label: "nm7.clearkey.hls"))
        session.addContentKeyRecipient(asset)
        clearKeySession = session

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8
        observe(item: item, channel: channel, allowVLCFallback: false)
        engine = .avPlayer
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func startFairPlay(channel: Channel, drm: DRMInfo, headers: [String: String]) {
        guard let certificateURL = drm.certificateURL, let licenseURL = drm.licenseURL else {
            showError("Kênh FairPlay thiếu certificate URL hoặc license URL.")
            return
        }
        let asset = AVURLAsset(url: channel.streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let loader = FairPlayKeyLoader(
            certificateURL: certificateURL,
            licenseURL: licenseURL,
            headers: drm.licenseHeaders.merging(channel.httpHeaders) { a, _ in a }
        )
        fairPlayLoader = loader
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "nm7.fairplay"))
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8
        observe(item: item, channel: channel, allowVLCFallback: false)
        engine = .avPlayer
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func startAVPlayer(channel: Channel, headers: [String: String]) {
        let asset = AVURLAsset(url: channel.streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8
        observe(item: item, channel: channel, allowVLCFallback: true)
        engine = .avPlayer
        player.replaceCurrentItem(with: item)
        player.play()

        fallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, self.engine == .avPlayer,
                  self.player.timeControlStatus != .playing else { return }
            self.startVLCFallback(for: channel)
        }
    }

    private func observe(item: AVPlayerItem, channel: Channel, allowVLCFallback: Bool) {
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                case .failed:
                    if allowVLCFallback {
                        self.startVLCFallback(for: channel)
                    } else {
                        self.showError(item.error?.localizedDescription ?? "Không mở được luồng.")
                    }
                default:
                    break
                }
            }
        }
    }

    private func startVLCFallback(for channel: Channel) {
        guard currentChannel?.id == channel.id, engine == .avPlayer else { return }
        fallbackTask?.cancel()
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)

        let media = VLCMedia(url: channel.streamURL)
        var options: [String: Any] = ["network-caching": 1800, "clock-jitter": 0, "clock-synchro": 0]
        for (name, value) in channel.httpHeaders {
            switch name.lowercased() {
            case "user-agent": options["http-user-agent"] = value
            case "referer": options["http-referrer"] = value
            case "cookie": options["http-cookie"] = value
            default: options["http-header"] = "\(name): \(value)"
            }
        }
        if options["http-user-agent"] == nil { options["http-user-agent"] = "NM7-TV-iOS/1.0.69" }
        media.addOptions(options)
        engine = .vlc
        isLoading = true
        vlcPlayer.drawable = vlcDrawable
        vlcPlayer.media = media
        vlcPlayer.play()
    }

    func setLoading(_ value: Bool) { isLoading = value }

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
        dashItemObservation = nil
        clearKeySession = nil
        clearKeyDelegate = nil
        cencProcessor = nil
        fairPlayLoader = nil
        dashBridge = nil
        dashPlayer?.stop()
        dashPlayer = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        vlcPlayer.stop()
    }
}

private final class DashPlayerBridge: NSObject, UPlayerDelegate {
    weak var owner: ChannelPlayer?
    weak var playerView: UPlayerView?

    init(owner: ChannelPlayer) { self.owner = owner }

    func didEventPlayerStart(source: UPlayerProtocol) {
        Task { @MainActor in owner?.setLoading(true) }
    }
    func didEventPlayerPlay(source: UPlayerProtocol) {
        Task { @MainActor in owner?.setLoading(false) }
    }
    func didEventPlayerStop(source: UPlayerProtocol, error: Error?) {
        Task { @MainActor in
            owner?.setLoading(false)
            if let error { owner?.showError("DASH/ClearKey: \(error.localizedDescription)") }
        }
    }
    func didEventPlayerChange(source: UPlayerProtocol, isPaused: Bool) {}
    func didEventPlayerChange(source: UPlayerProtocol, isMuted: Bool) {}
    func didEventPlayerChange(source: UPlayerProtocol, rate: Double) {}
    func didEventPlayerChange(source: UPlayerProtocol, playingTime: TimeInterval) {}
    func didEventPlayerChange(source: UPlayerProtocol, duration: TimeInterval) {}
}

extension ChannelPlayer: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification!) {
        Task { @MainActor [weak self] in
            guard let self, self.engine == .vlc else { return }
            switch self.vlcPlayer.state {
            case .playing: self.isLoading = false; self.errorMessage = nil
            case .buffering, .opening: self.isLoading = true
            case .error: self.isLoading = false; self.errorMessage = "Không mở được luồng bằng AVPlayer/VLC."
            case .ended, .stopped: self.isLoading = false
            default: break
            }
        }
    }
    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification!) {}
}
