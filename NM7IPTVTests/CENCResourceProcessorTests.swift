import XCTest
@testable import NM7IPTV

final class CENCResourceProcessorTests: XCTestCase {
    private let kid = Data((0..<16).map { UInt8($0 + 1) })


    func testCENCFragmentIsDecryptedWithInlineClearKey() async throws {
        let kidHex = "00112233445566778899aabbccddeeff"
        let keyHex = "ffeeddccbbaa99887766554433221100"
        let iv = Data(hex: "00112233445566778899aabbccddeeff")
        let ciphertext = Data(hex: "94073fd2b9d7fd5a3f6e42407e0d358742e1f1154484b1be22cf16ea75dcdb70")
        let expected = Data("NM7-CENC-TEST-PAYLOAD-1234567890".utf8)

        let drm = DRMInfo.from(options: [
            "#KODIPROP:inputstream.adaptive.license_type=org.w3.clearkey",
            "#KODIPROP:inputstream.adaptive.license_key=\(kidHex):\(keyHex)"
        ])
        let processor = CENCResourceProcessor(drm: drm, headers: [:])

        let tkhd = makeFullBoxBox(type: "tkhd", version: 0, flags: 0, body: {
            var body = Data(repeating: 0, count: 16)
            body.replaceSubrange(12..<16, with: [0, 0, 0, 1])
            return body
        }())
        let tenc = makeTENC(version: 0, isProtected: 1, ivSize: 16, kid: Data(hex: kidHex))
        let moov = makeBox("moov", tkhd + makeBox("tenc", tenc.dropFirst(8)))

        let tfhd = makeFullBoxBox(type: "tfhd", version: 0, flags: 0, body: Data([0, 0, 0, 1]))
        let senc = makeFullBoxBox(type: "senc", version: 0, flags: 0, body:
            Data([0, 0, 0, 1]) + iv
        )
        let sampleSize = UInt32(ciphertext.count)

        var trun = makeTRUN(dataOffset: 0, sampleSize: sampleSize)
        let traf1 = makeBox("traf", tfhd + trun + senc)
        let moof1 = makeBox("moof", traf1)
        let dataOffset = Int32(moof1.count + 8)
        trun = makeTRUN(dataOffset: dataOffset, sampleSize: sampleSize)
        let moof = makeBox("moof", makeBox("traf", tfhd + trun + senc))
        let fragment = moof + makeBox("mdat", ciphertext)

        _ = try await processor.processMediaData(moov, sourceURL: URL(string: "https://example.test/init.mp4")!)
        let decrypted = try await processor.processMediaData(fragment, sourceURL: URL(string: "https://example.test/seg.m4s")!)

        XCTAssertEqual(
            decrypted.subdata(in: (moof.count + 8)..<(moof.count + 8 + expected.count)),
            expected
        )
    }

    private func makeTRUN(dataOffset: Int32, sampleSize: UInt32) -> Data {
        var body = Data([0, 0, 0, 1]) // sample_count = 1
        body.append(contentsOf: [
            UInt8((UInt32(bitPattern: dataOffset) >> 24) & 0xFF),
            UInt8((UInt32(bitPattern: dataOffset) >> 16) & 0xFF),
            UInt8((UInt32(bitPattern: dataOffset) >> 8) & 0xFF),
            UInt8(UInt32(bitPattern: dataOffset) & 0xFF)
        ])
        body.append(contentsOf: [
            UInt8((sampleSize >> 24) & 0xFF),
            UInt8((sampleSize >> 16) & 0xFF),
            UInt8((sampleSize >> 8) & 0xFF),
            UInt8(sampleSize & 0xFF)
        ])
        return makeFullBoxBox(type: "trun", version: 0, flags: 0x000201, body: body)
    }

    private func makeFullBoxBox(type: String, version: UInt8, flags: UInt32, body: Data) -> Data {
        var full = Data([version,
                         UInt8((flags >> 16) & 0xFF),
                         UInt8((flags >> 8) & 0xFF),
                         UInt8(flags & 0xFF)])
        full.append(body)
        return makeBox(type, full)
    }

    private func makeBox(_ type: String, _ body: Data) -> Data {
        let size = UInt32(8 + body.count)
        var result = Data([
            UInt8((size >> 24) & 0xFF),
            UInt8((size >> 16) & 0xFF),
            UInt8((size >> 8) & 0xFF),
            UInt8(size & 0xFF)
        ])
        result.append(contentsOf: type.utf8.prefix(4))
        result.append(body)
        return result
    }

    func testTencVersion0UsesCorrectOffsets() {
        let tenc = makeTENC(version: 0, isProtected: 1, ivSize: 8, kid: kid)
        let parsed = CENCResourceProcessor.parseTENC(data: tenc, offset: 0, size: tenc.count)

        XCTAssertEqual(parsed?.version, 0)
        XCTAssertEqual(parsed?.isProtected, 1)
        XCTAssertEqual(parsed?.ivSize, 8)
        XCTAssertEqual(parsed?.kid, kid)
        XCTAssertNil(parsed?.constantIV)
    }

    func testTencVersion1UsesSameKidOffsetsAndPatternByteIsNotIVSize() {
        let tenc = makeTENC(version: 1, isProtected: 1, ivSize: 16, kid: kid, cryptSkip: 0x00)
        let parsed = CENCResourceProcessor.parseTENC(data: tenc, offset: 0, size: tenc.count)

        XCTAssertEqual(parsed?.version, 1)
        XCTAssertEqual(parsed?.isProtected, 1)
        XCTAssertEqual(parsed?.ivSize, 16)
        XCTAssertEqual(parsed?.kid, kid)
    }

    func testTencConstantIVIsReadAfterKid() {
        let constantIV = Data([0, 1, 2, 3, 4, 5, 6, 7])
        let tenc = makeTENC(version: 0, isProtected: 1, ivSize: 0, kid: kid, constantIV: constantIV)
        let parsed = CENCResourceProcessor.parseTENC(data: tenc, offset: 0, size: tenc.count)

        XCTAssertEqual(parsed?.ivSize, 0)
        XCTAssertEqual(parsed?.kid, kid)
        XCTAssertEqual(parsed?.constantIV, constantIV)
    }

    func testMalformedTencIsRejected() {
        let tenc = makeTENC(version: 0, isProtected: 1, ivSize: 8, kid: kid)
        XCTAssertNil(CENCResourceProcessor.parseTENC(data: tenc, offset: 0, size: tenc.count - 1))
    }

    private func makeTENC(
        version: UInt8,
        isProtected: UInt8,
        ivSize: UInt8,
        kid: Data,
        cryptSkip: UInt8 = 0,
        constantIV: Data? = nil
    ) -> Data {
        var body = Data([0, cryptSkip, isProtected, ivSize])
        body.append(kid)

        if isProtected == 1 && ivSize == 0, let constantIV {
            body.append(UInt8(constantIV.count))
            body.append(constantIV)
        }

        var data = Data()
        let size = UInt32(12 + body.count)
        data.append(contentsOf: [
            UInt8((size >> 24) & 0xFF),
            UInt8((size >> 16) & 0xFF),
            UInt8((size >> 8) & 0xFF),
            UInt8(size & 0xFF),
            0x74, 0x65, 0x6E, 0x63,
            version, 0, 0, 0
        ])
        data.append(body)
        return data
    }
}


private extension Data {
    init(hex: String) {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        self = data
    }
}
