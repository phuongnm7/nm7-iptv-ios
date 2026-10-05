import AVFoundation
import XCTest
@testable import NM7IPTV

final class ClearKeyPlaybackIntegrationTests: XCTestCase {
    @MainActor
    func testPublicClearKeyDASHAdvancesPlayback() async throws {
        let channel = Channel(
            name: "Public ClearKey DASH integration",
            group: "Integration",
            logoURL: nil,
            streamURL: URL(string: "https://yt-dash-mse-test.commondatastorage.googleapis.com/media/car_cenc-20120827-manifest.mpd")!,
            options: [
                "#KODIPROP:inputstream.adaptive.manifest_type=mpd",
                "#KODIPROP:inputstream.adaptive.license_type=clearkey",
                "#KODIPROP:inputstream.adaptive.license_key=kid=60061e017e477e877e57d00d1ed00d1e&key=1a8a2095e4deb2d29ec816ac7bae2082"
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
                XCTFail("ClearKey AVPlayerItem failed: \(item?.error?.localizedDescription ?? "unknown error")")
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
