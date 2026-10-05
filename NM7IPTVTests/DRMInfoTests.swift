import XCTest
@testable import NM7IPTV

final class DRMInfoTests: XCTestCase {
    func testFairPlayMetadataIsRecognized() {
        let info = DRMInfo.from(options: [
            "#KODIPROP:inputstream.adaptive.license_type=fairplay",
            "#KODIPROP:inputstream.adaptive.license_key=https://license.example/fps|Authorization=Bearer%20abc",
            "#KODIPROP:inputstream.adaptive.certificate_url=https://license.example/cert.cer"
        ])

        XCTAssertTrue(info.isNativeFairPlay)
        XCTAssertEqual(info.licenseURL?.absoluteString, "https://license.example/fps")
        XCTAssertEqual(info.certificateURL?.absoluteString, "https://license.example/cert.cer")
        XCTAssertEqual(info.licenseHeaders["Authorization"], "Bearer abc")
    }

    func testAndroidOnlyDRMIsNotMarkedAsNativeFairPlay() {
        XCTAssertEqual(
            DRMInfo.from(options: ["#KODIPROP:inputstream.adaptive.license_type=widevine"]).system,
            .widevine
        )
        XCTAssertEqual(
            DRMInfo.from(options: ["#KODIPROP:inputstream.adaptive.license_type=clearkey"]).system,
            .clearKey
        )
    }
}