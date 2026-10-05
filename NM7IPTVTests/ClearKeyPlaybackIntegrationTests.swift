import AVFoundation
import XCTest
@testable import NM7IPTV

final class ClearKeyPlaybackIntegrationTests: XCTestCase {
    @MainActor
    func testPublicClearKeyDASHAdvancesPlayback() async throws {
        let channel = Channel(
            name: "Public ClearKey DASH SegmentTemplate integration",
            group: "Integration",
            logoURL: nil,
            streamURL: URL(string: "https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p_ClearKey.mpd")!,
            options: [
                "#KODIPROP:inputstream.adaptive.manifest_type=mpd",
                "#KODIPROP:inputstream.adaptive.license_type=clearkey",
                "#KODIPROP:inputstream.adaptive.license_key=kid=f3d73b3a9b89462ebf7911004ea3b3b9&key=2e547a81ff90aa02648cb9e3f79e7339"
            ]
        )
        try await assertPlayback(channel)
    }

    @MainActor
    func testRealOnSportsChannelsFromPublicTelevisionPlaylist() async throws {
        let playlistURL = URL(string: "https://raw.githubusercontent.com/phuongnm7/Iptv-phuongnm7/main/IPTV_Gop_VMTTV_vAppTV.m3u")!
        var request = URLRequest(url: playlistURL)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        let playlist = String(decoding: data, as: UTF8.self)
        let channels = M3UParser.parse(playlist).channels
        for name in ["On Sports 50fps", "On Sports + 50fps"] {
            guard let channel = channels.first(where: { $0.name == name }) else {
                XCTFail("The public television playlist does not contain \(name).")
                return
            }
            XCTAssertTrue(channel.isDASH, "\(name) must route through the DASH/ClearKey engine.")
            XCTAssertEqual(DRMInfo.from(options: channel.options).system, .clearKey)

            var manifestRequest = URLRequest(url: channel.streamURL)
            manifestRequest.timeoutInterval = 15
            manifestRequest.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            channel.httpHeaders.forEach {
                manifestRequest.setValue($0.value, forHTTPHeaderField: $0.key)
            }
            do {
                let (manifestData, manifestResponse) = try await URLSession.shared.data(for: manifestRequest)
                guard let http = manifestResponse as? HTTPURLResponse else {
                    XCTFail("\(name) returned a non-HTTP manifest response (\(String(describing: manifestResponse.mimeType))).")
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    XCTFail("\(name) manifest request returned HTTP \(http.statusCode), MIME \(http.mimeType ?? "unknown").")
                    continue
                }
                let prefix = String(decoding: manifestData.prefix(512), as: UTF8.self)
                XCTAssertTrue(
                    prefix.contains("<MPD") || (http.mimeType?.localizedCaseInsensitiveContains("dash") ?? false),
                    "\(name) manifest response is not DASH XML (MIME \(http.mimeType ?? "unknown"))."
                )
            } catch {
                XCTFail("\(name) manifest request failed before HTTP response: \(error.localizedDescription)")
                continue
            }
            try await assertPlayback(channel)
        }
    }

    @MainActor
    private func assertPlayback(_ channel: Channel) async throws {
        let player = ChannelPlayer()
        defer { player.stop() }

        player.play(channel)
        XCTAssertEqual(player.engine, .dashClearKey, "\(channel.name) was not routed to the DASH/ClearKey engine.")
        let deadline = ContinuousClock.now + .seconds(50)

        while ContinuousClock.now < deadline {
            if let message = player.errorMessage {
                XCTFail("\(channel.name) returned a player error: \(message)")
                return
            }

            let item = player.activeAVPlayer.currentItem
            if item?.status == .failed {
                let events = item?.errorLog()?.events.map {
                    "status=\($0.errorStatusCode), domain=\($0.errorDomain), comment=\($0.errorComment ?? "none")"
                }.joined(separator: " | ") ?? "no AVPlayer error events"
                XCTFail("\(channel.name) AVPlayerItem failed: \(item?.error?.localizedDescription ?? "unknown error"); \(events)")
                return
            }

            let position = player.activeAVPlayer.currentTime().seconds
            if item?.status == .readyToPlay,
               player.activeAVPlayer.timeControlStatus == .playing,
               position.isFinite,
               position >= 2 {
                return
            }

            try await Task.sleep(for: .milliseconds(250))
        }

        let finalState = player.activeAVPlayer.currentItem?.status.rawValue ?? -1
        let finalTime = player.activeAVPlayer.currentTime().seconds
        XCTFail("\(channel.name) did not advance after 50 seconds (itemStatus=\(finalState), time=\(finalTime), error=\(player.errorMessage ?? "none")).")
    }
}
