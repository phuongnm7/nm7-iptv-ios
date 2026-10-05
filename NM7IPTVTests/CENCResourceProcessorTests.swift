import XCTest
@testable import NM7IPTV

final class CENCResourceProcessorTests: XCTestCase {
    private let kid = Data((0..<16).map { UInt8($0 + 1) })

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
