import XCTest
@testable import NM7IPTV

final class M3UParserTests: XCTestCase {
    func testParsesGroupsLogosAndHeaders() {
        let input = """
        #EXTM3U
        #EXTINF:-1 tvg-logo="https://example.com/vtv1.png" group-title="VTV",VTV1
        #EXTVLCOPT:http-user-agent=NM7-Test
        https://example.com/live/vtv1.m3u8
        """
        let channels = M3UParser.parse(input)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels[0].name, "VTV1")
        XCTAssertEqual(channels[0].group, "VTV")
        XCTAssertEqual(channels[0].userAgent, "NM7-Test")
    }

    func testIgnoresInvalidEntries() {
        XCTAssertTrue(M3UParser.parse("#EXTM3U\n#EXTINF:-1,Invalid\nnot a url").isEmpty)
    }
}
