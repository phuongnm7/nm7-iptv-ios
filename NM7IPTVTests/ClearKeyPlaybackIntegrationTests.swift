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
        let player = ChannelPlayer()
        defer { player.stop() }

        player.play(channel)
        let deadline = ContinuousClock.now + .seconds(50)

        while ContinuousClock.now < deadline {
            if let message = player.errorMessage {
                XCTFail("ClearKey player returned an error: \(message)")
                return
            }

            let item = player.activeAVPlayer.currentItem
            if item?.status == .failed {
                let events = item?.errorLog()?.events.map {
                    "uri=\($0.uri ?? "none"), status=\($0.errorStatusCode), domain=\($0.errorDomain), comment=\($0.errorComment ?? "none")"
                }.joined(separator: " | ") ?? "no AVPlayer error events"
                XCTFail("ClearKey AVPlayerItem failed: \(item?.error?.localizedDescription ?? "unknown error"); \(events)")
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
        XCTFail("ClearKey DASH did not advance after 50 seconds (itemStatus=\(finalState), time=\(finalTime), error=\(player.errorMessage ?? "none")).")
    }
}
