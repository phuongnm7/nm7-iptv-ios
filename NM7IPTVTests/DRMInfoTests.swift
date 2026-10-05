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

    func testAndroidLegacyDRMMetadataIsRecognized() {
        let info = DRMInfo.from(options: [
            "#KODIPROP:inputstream.adaptive.drm_legacy=org.w3.clearkey|https://license.example/clearkey|Authorization=Bearer%20abc"
        ])

        XCTAssertEqual(info.system, .clearKey)
        XCTAssertEqual(info.licenseURL?.absoluteString, "https://license.example/clearkey")
        XCTAssertEqual(info.licenseHeaders["Authorization"], "Bearer abc")
        XCTAssertFalse(info.isNativeFairPlay)
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
    func testInlineClearKeyIsPreservedAsLicenseValue() {
        let info = DRMInfo.from(options: [
            "#KODIPROP:inputstream.adaptive.license_type=org.w3.clearkey",
            "#KODIPROP:inputstream.adaptive.license_key=00112233445566778899aabbccddeeff:ffeeddccbbaa99887766554433221100"
        ])

        XCTAssertEqual(info.system, .clearKey)
        XCTAssertEqual(
            info.licenseValue,
            "00112233445566778899aabbccddeeff:ffeeddccbbaa99887766554433221100"
        )
        XCTAssertNil(info.licenseURL)
    }


    func testClearKeyNamedPairMatchesAndroidFormat() {
        let pairs = ClearKeyContentKeySession.parsePairs(
            "kid=00112233445566778899aabbccddeeff&key=ffeeddccbbaa99887766554433221100"
        )

        let kid = Data([0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xaa,0xbb,0xcc,0xdd,0xee,0xff])
        XCTAssertEqual(pairs[kid.base64URLEncodedString]?.count, 16)
    }

}