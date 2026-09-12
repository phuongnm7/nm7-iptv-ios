import XCTest
@testable import NM7IPTV

final class VoiceChannelMatcherTests: XCTestCase {
    private let channels = [
        Channel(name: "VTV1", group: "VTV", logoURL: nil, streamURL: URL(string: "https://example.com/1.m3u8")!),
        Channel(name: "Thể Thao TV", group: "Thể thao", logoURL: nil, streamURL: URL(string: "https://example.com/2.m3u8")!)
    ]

    func testMatchesVietnameseCommand() {
        XCTAssertEqual(VoiceChannelMatcher.bestMatch(for: "Mở kênh VTV1", channels: channels)?.name, "VTV1")
    }

    func testMatchesWithoutDiacritics() {
        XCTAssertEqual(VoiceChannelMatcher.bestMatch(for: "xem kenh the thao tv", channels: channels)?.name, "Thể Thao TV")
    }
}
