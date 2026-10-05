import XCTest
@testable import NM7IPTV

final class ChannelLogoResolverTests: XCTestCase {
    func testVtvCabSportsUsesAndroidSourceOfTruthLogo() {
        let channel = Channel(
            name: "ON SPORTS",
            group: "VTVcab",
            tvgID: "vtvcab3hd",
            logoURL: URL(string: "https://wrong.example/logo.png"),
            streamURL: URL(string: "https://example.com/live.m3u8")!
        )

        XCTAssertTrue(ChannelLogoResolver.isAffected(channel))
        XCTAssertEqual(
            ChannelLogoResolver.candidates(for: channel).first,
            "https://cdn.hqth.me/logo/thumbs/14.png"
        )
    }
}