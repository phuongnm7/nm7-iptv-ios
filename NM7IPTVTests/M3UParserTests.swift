import XCTest
@testable import NM7IPTV

final class M3UParserTests: XCTestCase {
    func testDetectsExpiredSignedTV360URL() throws {
        let channel = Channel(
            name: "ON SPORTS",
            group: "VTVcab",
            logoURL: nil,
            streamURL: URL(string: "https://example.com/tv360.php?id=173&expires=1788503111&token=redacted")!
        )
        XCTAssertEqual(channel.signedURLExpirationDate, Date(timeIntervalSince1970: 1_788_503_111))
        XCTAssertTrue(channel.hasExpiredSignedURL(now: Date(timeIntervalSince1970: 1_791_170_000)))
    }

    func testParsesGroupsLogosVLCHeadersAndEPG() throws {
        let input = """
        #EXTM3U url-tvg="https://example.com/epg.xml"
        #EXTINF:-1 tvg-id="vtv1" tvg-logo="https://example.com/vtv1.png" group-title="VTV",VTV1
        #KODIPROP:inputstream.adaptive.manifest_type=hls
        #EXTVLCOPT:http-user-agent=NM7-Test
        https://example.com/live/vtv1.m3u8
        """
        let result = M3UParser.parse(input)
        let channel = try XCTUnwrap(result.channels.first)
        XCTAssertEqual(channel.name, "VTV1")
        XCTAssertEqual(channel.group, "VTV")
        XCTAssertEqual(channel.userAgent, "NM7-Test")
        XCTAssertTrue(channel.isHLS)
        XCTAssertEqual(result.epgURL?.absoluteString, "https://example.com/epg.xml")
    }

    func testSupportsExtGrpAndRelativeUrls() throws {
        let input = """
        #EXTM3U
        #EXTINF:-1 tvg-logo="logos/vtv.png",VTV2
        #EXTGRP:VTV
        /live/vtv2.m3u8
        """
        let base = URL(string: "https://example.com/playlist.m3u")!
        let channel = try XCTUnwrap(M3UParser.parse(input, baseURL: base).channels.first)
        XCTAssertEqual(channel.group, "VTV")
        XCTAssertEqual(channel.streamURL.absoluteString, "https://example.com/live/vtv2.m3u8")
        XCTAssertEqual(channel.logoURL?.absoluteString, "https://example.com/logos/vtv.png")
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

    
    func testVTVBackupWidevineIsReplacedByNonDRMHLS() throws {
        let input = """
        #EXTM3U
        #EXTINF:-1 tvg-id="vtv9hd" group-title="VTV",VTV9
        https://example.com/vtv9.m3u8

        #EXTINF:-1 tvg-id="vstv455" group-title="Dự phòng",VTV9
        #KODIPROP:inputstream.adaptive.manifest_type=mpd
        #KODIPROP:inputstream.adaptive.license_type=widevine
        #KODIPROP:inputstream.adaptive.license_key=https://license.example/key
        https://example.com/backup/vtv9/manifest.mpd
        """

        let result = M3UParser.parse(input)
        let backup = try XCTUnwrap(result.channels.first(where: { $0.group == "VTV dự phòng" }))

        XCTAssertEqual(backup.name, "VTV9")
        XCTAssertEqual(backup.streamURL.absoluteString, "https://example.com/vtv9.m3u8")
        XCTAssertTrue(backup.isHLS)
        XCTAssertFalse(backup.isLikelyDRM)
        XCTAssertTrue(backup.options.contains("#NM7-IOS-VTV-BACKUP-HLS"))
    }

    func testDirectSportsHTTPStreamsPreferVLC() {
        let text = """
        #EXTM3U
        #EXTINF:-1 group-title="Thể thao",SPORT EVENT 1
        http://mag.tivi-one-iptv.net:80/play/live.php?stream=1313248&extension=ts&play_token=abc
        #EXTINF:-1 group-title="Thể thao",SPORT EVENT 2
        http://zazaint.com:80/MAGU52TLAM/SAAk0NZH71/17281
        #EXTINF:-1 group-title="Thể thao",SPORT EVENT 3
        https://cdn.example.com/live/channel.m3u8
        """
        let parsed = M3UParser.parse(text)
        XCTAssertEqual(parsed.channels.count, 3)
        XCTAssertTrue(parsed.channels[0].prefersVLC)
        XCTAssertTrue(parsed.channels[1].prefersVLC)
        XCTAssertFalse(parsed.channels[2].prefersVLC)
        XCTAssertTrue(parsed.channels[2].isHLS)
    }

}
