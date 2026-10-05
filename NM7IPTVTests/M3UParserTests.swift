import XCTest
@testable import NM7IPTV

final class M3UParserTests: XCTestCase {
    func testParsesGroupsLogosVLCHeadersAndEPG() throws {
        let input = """
        #EXTM3U url-tvg="https://example.com/epg.xml"
        #EXTINF:-1 tvg-id="vtv1" tvg-logo="https://example.com/vtv1.png" group-title="VTV",VTV1
        #KODIPROP:inputstream.adaptive.manifest_type=hls
        #EXTVLCOPT:http-user-agent=NM7-Test
        https://example.com/live/vtv1.m3u8
        """
        let result = M3UParser.parse(input)
        XCTAssertEqual(result.channels.count, 1)
        XCTAssertEqual(result.channels[0].name, "VTV1")
        XCTAssertEqual(result.channels[0].group, "VTV")
        XCTAssertEqual(result.channels[0].tvgID, "vtv1")
        XCTAssertEqual(result.channels[0].userAgent, "NM7-Test")
        XCTAssertTrue(result.channels[0].isHLS)
        XCTAssertEqual(result.epgURL?.absoluteString, "https://example.com/epg.xml")
    }

    func testSplitsInlineURLHeaders() throws {
        let input = """
        #EXTM3U
        #EXTINF:-1 group-title="VTV",VTV2
        https://example.com/live?id=2|User-Agent=Mozilla%2F5.0&Referer=https%3A%2F%2Ftv.example%2F&Origin=https%3A%2F%2Ftv.example
        """
        let channel = try XCTUnwrap(M3UParser.parse(input).channels.first)
        XCTAssertEqual(channel.streamURL.absoluteString, "https://example.com/live?id=2")
        XCTAssertEqual(channel.httpHeaders["User-Agent"], "Mozilla/5.0")
        XCTAssertEqual(channel.httpHeaders["Referer"], "https://tv.example/")
        XCTAssertEqual(channel.httpHeaders["Origin"], "https://tv.example")
    }

    func testParsesExtHTTPJSONHeaders() throws {
        let input = """
        #EXTM3U
        #EXTINF:-1,Test
        #EXTHTTP:{"Cookie":"token=abc","User-Agent":"NM7"}
        https://example.com/live.m3u8
        """
        let channel = try XCTUnwrap(M3UParser.parse(input).channels.first)
        XCTAssertEqual(channel.httpHeaders["Cookie"], "token=abc")
        XCTAssertEqual(channel.httpHeaders["User-Agent"], "NM7")
    }

    func testIdentifiesDASHAndLikelyDRM() throws {
        let input = """
        #EXTM3U
        #EXTINF:-1 group-title="VTVcab",ON Sports
        #KODIPROP:inputstream.adaptive.manifest_type=mpd
        #KODIPROP:inputstream.adaptive.license_type=clearkey
        https://example.com/live/manifest.mpd
        """
        let channel = try XCTUnwrap(M3UParser.parse(input).channels.first)
        XCTAssertTrue(channel.isDASH)
        XCTAssertTrue(channel.isLikelyDRM)
    }

    func testIgnoresInvalidEntries() {
        XCTAssertTrue(M3UParser.parse("#EXTM3U\n#EXTINF:-1,Invalid\nnot a url").channels.isEmpty)
    }
}
