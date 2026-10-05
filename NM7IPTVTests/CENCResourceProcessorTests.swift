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
            var body = Data(repeating: 0, count: 12)
            body.replaceSubrange(8..<12, with: [0, 0, 0, 1])
            return body
        }())
        let tenc = makeTENC(version: 0, isProtected: 1, ivSize: 16, kid: Data(hex: kidHex))
        let trak = makeBox("trak", tkhd + tenc)
        let moov = makeBox("moov", trak)

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

    func testCENCDecryptsEveryMoofInOneSegmentBaseResource() async throws {
        let key = Data(hex: "ffeeddccbbaa99887766554433221100")
        let kid = Data(hex: "00112233445566778899aabbccddeeff")
        let iv1 = Data(hex: "00112233445566778899aabbccddeeff")
        let iv2 = Data(hex: "102132435465768798a9bacbdcedfe0f")
        let ct1 = Data(hex: "94073fd2b9d7fd5a3f6e42407e0d358742e1f1154484b1be22cf16ea75dcdb70")
        let ct2 = Data(hex: "9ecd0a06d2ae2e14c3986e69f7df21216f0e4cdcdd56beb851f243a9748a40")

        XCTAssertEqual(key.count, 16)
        XCTAssertEqual(kid.count, 16)

        let drm = DRMInfo.from(options: [
            "#KODIPROP:inputstream.adaptive.license_type=org.w3.clearkey",
            "#KODIPROP:inputstream.adaptive.license_key=00112233445566778899aabbccddeeff:ffeeddccbbaa99887766554433221100"
        ])
        let processor = CENCResourceProcessor(drm: drm, headers: [:])

        let tkhd = makeFullBoxBox(type: "tkhd", version: 0, flags: 0, body: {
            var body = Data(repeating: 0, count: 12)
            body.replaceSubrange(8..<12, with: [0, 0, 0, 1])
            return body
        }())
        let tenc = makeTENC(version: 0, isProtected: 1, ivSize: 16, kid: kid)
        let moov = makeBox("moov", makeBox("trak", tkhd + tenc))

        let firstTemplate = makeFragment(iv: iv1, ciphertext: ct1, dataOffset: 0)
        let firstMoof = makeFragment(iv: iv1, ciphertext: ct1, dataOffset: Int32(firstTemplate.count + 8))
        let firstMdat = makeBox("mdat", ct1)

        let secondTemplate = makeFragment(iv: iv2, ciphertext: ct2, dataOffset: 0)
        let secondPrefix = firstMoof.count + firstMdat.count
        let secondMoof = makeFragment(
            iv: iv2,
            ciphertext: ct2,
            dataOffset: Int32(secondPrefix + secondTemplate.count + 8)
        )
        let secondMdat = makeBox("mdat", ct2)

        _ = try await processor.processMediaData(
            moov,
            sourceURL: URL(string: "https://example.test/init.mp4")!
        )
        let result = try await processor.processMediaData(
            firstMoof + firstMdat + secondMoof + secondMdat,
            sourceURL: URL(string: "https://example.test/full.mp4")!
        )

        let expected1 = Data("NM7-CENC-TEST-PAYLOAD-1234567890".utf8)
        let expected2 = Data("NM7-CENC-SECOND-FRAGMENT-987654".utf8)

        let firstPayloadOffset = firstMoof.count + 8
        let secondPayloadOffset = secondPrefix + secondMoof.count + 8
        XCTAssertEqual(result.subdata(in: firstPayloadOffset..<(firstPayloadOffset + expected1.count)), expected1)
        XCTAssertEqual(result.subdata(in: secondPayloadOffset..<(secondPayloadOffset + expected2.count)), expected2)
    }

    private func makeFragment(iv: Data, ciphertext: Data, dataOffset: Int32) -> Data {
        let tfhd = makeFullBoxBox(type: "tfhd", version: 0, flags: 0, body: Data([0, 0, 0, 1]))
        let senc = makeFullBoxBox(type: "senc", version: 0, flags: 0, body: Data([0, 0, 0, 1]) + iv)
        let trun = makeTRUN(dataOffset: dataOffset, sampleSize: UInt32(ciphertext.count))
        return makeBox("moof", makeBox("traf", tfhd + trun + senc))
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
