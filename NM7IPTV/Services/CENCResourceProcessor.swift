import Foundation
import CommonCrypto

final class CENCResourceProcessor: NSObject, UPlayerMediaResourceProcessor {
    private struct TrackInfo {
        let kid: Data
        let ivSize: Int
        let constantIV: Data?
        let defaultSampleSize: Int
    }

    private struct Box {
        let offset: Int
        let size: Int
        let header: Int
        let type: String
        var end: Int { offset + size }
        var contentStart: Int { offset + header }
    }

    private struct SENCEntry {
        let iv: Data
        let subsamples: [(clear: Int, encrypted: Int)]?
    }

    private let drm: DRMInfo
    private let headers: [String: String]
    private let session: URLSession
    private let lock = NSLock()
    private var tracks: [UInt32: TrackInfo] = [:]
    private var keys: [String: Data] = [:]

    init(drm: DRMInfo, headers: [String: String]) {
        self.drm = drm
        self.headers = headers
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
        super.init()

        let pairs = ClearKeyContentKeySession.parsePairs(drm.licenseValue)
        for (kidString, key) in pairs {
            if let kid = ClearKeyContentKeySession.decodeKeyID(kidString) {
                keys[base64URL(kid)] = key
            }
        }
        if pairs.isEmpty, let data = drm.licenseValue.data(using: .utf8),
           let jwk = try? ClearKeyContentKeySession.parseJWK(data) {
            for (kidString, key) in jwk {
                if let kid = ClearKeyContentKeySession.decodeKeyID(kidString) {
                    keys[kid.base64EncodedString()] = key
                }
            }
        }
    }

    func processMediaData(_ data: Data, sourceURL: URL) async throws -> Data {
        if let moov = findTopLevelBox("moov", in: data) {
            parseTrackEncryption(data, moov: moov)
            return sanitizeInitialization(data)
        }
        if findTopLevelBox("moof", in: data) != nil {
            return try await decryptFragment(data)
        }
        return data
    }

    private func parseTrackEncryption(_ data: Data, moov: Box) {
        var trexDefaultSizes: [UInt32: Int] = [:]
        if let mvex = childBoxes(data, parent: moov).first(where: { $0.type == "mvex" }) {
            for trex in childBoxes(data, parent: mvex).filter({ $0.type == "trex" }) {
                guard trex.contentStart + 16 <= trex.end else { continue }
                let trackID = readUInt32(data, trex.contentStart + 4)
                let defaultSampleSize = Int(readUInt32(data, trex.contentStart + 16))
                trexDefaultSizes[trackID] = defaultSampleSize
            }
        }

        for trak in childBoxes(data, parent: moov).filter({ $0.type == "trak" }) {
            guard let tkhd = childBoxes(data, parent: trak).first(where: { $0.type == "tkhd" }),
                  let trackID = parseTrackID(data, tkhd: tkhd),
                  let tenc = findRawBox(type: "tenc", in: data, range: trak.offset..<trak.end),
                  let parsed = Self.parseTENC(data: data, offset: tenc.offset, size: tenc.size) else {
                continue
            }

            tracks[trackID] = TrackInfo(
                kid: parsed.kid,
                ivSize: parsed.ivSize,
                constantIV: parsed.constantIV,
                defaultSampleSize: trexDefaultSizes[trackID] ?? 0
            )
        }
    }

    /// Parses ISO/IEC 23001-7 TrackEncryptionBox.
    ///
    /// After the 8-byte BMFF header + 4-byte FullBox header, the tenc body is:
    ///   v0: reserved, reserved, isProtected, IVSize, KID[16]
    ///   v1+: reserved, crypt/skip, isProtected, IVSize, KID[16]
    /// Hence isProtected=+14, IVSize=+15, KID=+16 for both versions.
    static func parseTENC(data: Data, offset: Int, size: Int)
        -> (version: Int, isProtected: Int, ivSize: Int, kid: Data, constantIV: Data?)? {
        guard offset >= 0, size >= 32, offset + size <= data.count,
              data[offset + 4] == 0x74,
              data[offset + 5] == 0x65,
              data[offset + 6] == 0x6E,
              data[offset + 7] == 0x63 else {
            return nil
        }

        let version = Int(data[offset + 8])
        guard version == 0 || version >= 1 else { return nil }

        let isProtectedOffset = offset + 14
        let ivSizeOffset = offset + 15
        let kidOffset = offset + 16
        guard kidOffset + 16 <= offset + size else { return nil }

        let isProtected = Int(data[isProtectedOffset])
        let ivSize = Int(data[ivSizeOffset])
        let kid = data.subdata(in: kidOffset..<(kidOffset + 16))

        var constantIV: Data?
        if isProtected == 1 && ivSize == 0 {
            let constantSizeOffset = kidOffset + 16
            guard constantSizeOffset < offset + size else { return nil }
            let constantSize = Int(data[constantSizeOffset])
            guard constantSize > 0,
                  constantSize <= 16,
                  constantSizeOffset + 1 + constantSize <= offset + size else {
                return nil
            }
            constantIV = data.subdata(
                in: (constantSizeOffset + 1)..<(constantSizeOffset + 1 + constantSize)
            )
        }

        return (
            version: version,
            isProtected: isProtected,
            ivSize: ivSize,
            kid: kid,
            constantIV: constantIV
        )
    }
    private func decryptFragment(_ source: Data) async throws -> Data {
        guard let moof = findTopLevelBox("moof", in: source) else { return source }
        var output = source

        for traf in childBoxes(source, parent: moof).filter({ $0.type == "traf" }) {
            guard let tfhd = childBoxes(source, parent: traf).first(where: { $0.type == "tfhd" }),
                  let trun = childBoxes(source, parent: traf).first(where: { $0.type == "trun" }) else {
                continue
            }

            let trackID = readUInt32(source, tfhd.contentStart + 4)
            guard let info = tracks[trackID] else {
                // No tenc in the initialization segment means this track is not
                // one of the CENC tracks handled by this processor.
                continue
            }

            let tfhdFlags = fullBoxFlags(source, tfhd)
            var tfhdCursor = tfhd.contentStart + 4
            tfhdCursor += 4 // track_ID

            var baseOffset = moof.offset
            if (tfhdFlags & 0x000001) != 0 {
                guard tfhdCursor + 8 <= tfhd.end else {
                    throw error("tfhd thiếu base-data-offset.")
                }
                let raw = readUInt64(source, tfhdCursor)
                guard raw <= UInt64(Int.max) else {
                    throw error("tfhd base-data-offset quá lớn.")
                }
                baseOffset = Int(raw)
                tfhdCursor += 8
            }
            if (tfhdFlags & 0x000002) != 0 { tfhdCursor += 4 }

            var defaultSampleSize = 0
            if (tfhdFlags & 0x000008) != 0 { tfhdCursor += 4 }
            if (tfhdFlags & 0x000010) != 0 {
                guard tfhdCursor + 4 <= tfhd.end else {
                    throw error("tfhd thiếu default sample size.")
                }
                defaultSampleSize = Int(readUInt32(source, tfhdCursor))
                tfhdCursor += 4
            }
            if defaultSampleSize == 0 {
                defaultSampleSize = info.defaultSampleSize
            }

            let (dataOffset, sampleSizes) = try parseTRUN(
                source,
                box: trun,
                baseOffset: baseOffset,
                fallback: moof.end,
                defaultSampleSize: defaultSampleSize
            )

            let trafChildren = childBoxes(source, parent: traf)
            let entries: [SENCEntry]
            if let senc = trafChildren.first(where: { $0.type == "senc" }) {
                entries = try parseSENC(
                    source,
                    box: senc,
                    ivSize: info.ivSize,
                    constantIV: info.constantIV
                )
            } else if let saiz = trafChildren.first(where: { $0.type == "saiz" }),
                      let saio = trafChildren.first(where: { $0.type == "saio" }) {
                entries = try parseAuxiliaryEncryption(
                    source,
                    saiz: saiz,
                    saio: saio,
                    baseOffset: baseOffset,
                    ivSize: info.ivSize,
                    constantIV: info.constantIV,
                    sampleCount: sampleSizes.count
                )
            } else {
                throw error("CENC fragment thiếu senc hoặc saiz/saio cho track \(trackID).")
            }

            guard entries.count == sampleSizes.count else {
                throw error("CENC encryption/sample count không khớp (enc=\(entries.count), trun=\(sampleSizes.count)).")
            }

            var sampleOffset = dataOffset
            for index in 0..<entries.count {
                let size = sampleSizes[index]
                guard size > 0, sampleOffset >= 0, sampleOffset + size <= output.count else {
                    throw error("CENC sample range không hợp lệ.")
                }

                var sample = output.subdata(in: sampleOffset..<(sampleOffset + size))
                try decryptSample(
                    &sample,
                    key: try await key(for: info.kid),
                    iv: entries[index].iv,
                    subsamples: entries[index].subsamples
                )
                output.replaceSubrange(sampleOffset..<(sampleOffset + size), with: sample)
                sampleOffset += size
            }
        }

        return output
    }

    private func parseAuxiliaryEncryption(
        _ data: Data,
        saiz: Box,
        saio: Box,
        baseOffset: Int,
        ivSize: Int,
        constantIV: Data?,
        sampleCount: Int
    ) throws -> [SENCEntry] {
        let sizes = try parseSAIZ(data, box: saiz)
        guard sizes.count == sampleCount else {
            throw error("CENC saiz/trun sample count không khớp.")
        }

        let offsets = try parseSAIO(data, box: saio)
        guard let first = offsets.first, first <= UInt64(Int.max) else {
            throw error("CENC saio không có offset hợp lệ.")
        }

        let relative = Int(first)
        let candidates = [baseOffset + relative, relative].filter {
            $0 >= 0 && $0 < data.count
        }

        guard let auxStart = candidates.first(where: { start in
            start + sizes.reduce(0, +) <= data.count
        }) else {
            throw error("CENC saio trỏ ra ngoài fragment.")
        }

        var cursor = auxStart
        var result: [SENCEntry] = []
        result.reserveCapacity(sampleCount)

        for size in sizes {
            guard size >= 0, cursor + size <= data.count else {
                throw error("CENC sample auxiliary data vượt kích thước fragment.")
            }
            let end = cursor + size
            let iv: Data
            if ivSize > 0 {
                guard cursor + ivSize <= end else { throw error("CENC auxiliary data thiếu IV.") }
                iv = data.subdata(in: cursor..<(cursor + ivSize))
                cursor += ivSize
            } else {
                guard let constantIV else { throw error("CENC thiếu constant IV.") }
                iv = constantIV
            }

            var subs: [(clear: Int, encrypted: Int)]?
            if cursor < end {
                guard cursor + 2 <= end else { throw error("CENC auxiliary data thiếu subsample count.") }
                let count = Int(readUInt16(data, cursor))
                cursor += 2
                var items: [(clear: Int, encrypted: Int)] = []
                items.reserveCapacity(count)
                for _ in 0..<count {
                    guard cursor + 6 <= end else { throw error("CENC auxiliary subsample thiếu dữ liệu.") }
                    items.append((
                        clear: Int(readUInt16(data, cursor)),
                        encrypted: Int(readUInt32(data, cursor + 2))
                    ))
                    cursor += 6
                }
                subs = items
            }

            guard cursor <= end else { throw error("CENC auxiliary data bị tràn.") }
            result.append(SENCEntry(iv: iv, subsamples: subs))
            cursor = end
        }

        return result
    }

    private func parseSAIZ(_ data: Data, box: Box) throws -> [Int] {
        let flags = fullBoxFlags(data, box)
        var cursor = box.contentStart

        if (flags & 0x000001) != 0 {
            guard cursor + 8 <= box.end else { throw error("saiz thiếu aux_info_type.") }
            cursor += 8
        }

        guard cursor + 5 <= box.end else { throw error("saiz thiếu sample count.") }
        let defaultSize = Int(data[cursor])
        cursor += 1
        let count = Int(readUInt32(data, cursor))
        cursor += 4

        if defaultSize != 0 {
            return Array(repeating: defaultSize, count: count)
        }

        guard cursor + count <= box.end else { throw error("saiz thiếu bảng sample info size.") }
        var result: [Int] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            result.append(Int(data[cursor]))
            cursor += 1
        }
        return result
    }

    private func parseSAIO(_ data: Data, box: Box) throws -> [UInt64] {
        let flags = fullBoxFlags(data, box)
        var cursor = box.contentStart

        if (flags & 0x000001) != 0 {
            guard cursor + 8 <= box.end else { throw error("saio thiếu aux_info_type.") }
            cursor += 8
        }

        guard cursor + 4 <= box.end else { throw error("saio thiếu entry count.") }
        let count = Int(readUInt32(data, cursor))
        cursor += 4

        let width = data[box.offset + 8] == 0 ? 4 : 8
        guard cursor + count * width <= box.end else { throw error("saio thiếu offset table.") }

        var result: [UInt64] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            if width == 4 {
                result.append(UInt64(readUInt32(data, cursor)))
                cursor += 4
            } else {
                result.append(readUInt64(data, cursor))
                cursor += 8
            }
        }
        return result
    }

    private func parseTRUN(
        _ data: Data,
        box: Box,
        baseOffset: Int,
        fallback: Int,
        defaultSampleSize: Int
    ) throws -> (Int, [Int]) {
        let flags = fullBoxFlags(data, box)
        var cursor = box.contentStart
        guard cursor + 4 <= box.end else { throw error("trun thiếu sample count.") }
        let count = Int(readUInt32(data, cursor))
        cursor += 4

        var dataOffset = fallback
        if (flags & 0x000001) != 0 {
            guard cursor + 4 <= box.end else { throw error("trun thiếu data offset.") }
            dataOffset = baseOffset + Int(readInt32(data, cursor))
            cursor += 4
        }
        if (flags & 0x000004) != 0 { cursor += 4 }

        var sizes: [Int] = []
        sizes.reserveCapacity(count)
        for _ in 0..<count {
            if (flags & 0x000100) != 0 { cursor += 4 }
            var size = defaultSampleSize
            if (flags & 0x000200) != 0 {
                guard cursor + 4 <= box.end else { throw error("trun thiếu sample size.") }
                size = Int(readUInt32(data, cursor))
                cursor += 4
            }
            if (flags & 0x000400) != 0 { cursor += 4 }
            if (flags & 0x000800) != 0 { cursor += 4 }
            guard cursor <= box.end else { throw error("trun vượt kích thước box.") }
            sizes.append(size)
        }

        guard sizes.allSatisfy({ $0 > 0 }) else {
            throw error("CENC cần sample-size trong trun hoặc tfhd.")
        }
        return (dataOffset, sizes)
    }

    private func parseSENC(_ data: Data, box: Box, ivSize: Int, constantIV: Data?) throws -> [SENCEntry] {
        let flags = fullBoxFlags(data, box)
        var cursor = box.contentStart
        guard cursor + 4 <= box.end else { throw error("senc thiếu sample count.") }
        let count = Int(readUInt32(data, cursor))
        cursor += 4

        var result: [SENCEntry] = []
        result.reserveCapacity(count)

        for _ in 0..<count {
            let iv: Data
            if ivSize > 0 {
                guard cursor + ivSize <= box.end else { throw error("senc thiếu IV.") }
                iv = data.subdata(in: cursor..<(cursor + ivSize))
                cursor += ivSize
            } else {
                guard let constantIV else { throw error("CENC thiếu constant IV.") }
                iv = constantIV
            }

            var subs: [(clear: Int, encrypted: Int)]?
            if (flags & 0x000002) != 0 {
                guard cursor + 2 <= box.end else { throw error("senc thiếu subsample count.") }
                let n = Int(readUInt16(data, cursor))
                cursor += 2
                var items: [(clear: Int, encrypted: Int)] = []
                items.reserveCapacity(n)
                for _ in 0..<n {
                    guard cursor + 6 <= box.end else { throw error("senc subsample thiếu dữ liệu.") }
                    items.append((
                        clear: Int(readUInt16(data, cursor)),
                        encrypted: Int(readUInt32(data, cursor + 2))
                    ))
                    cursor += 6
                }
                subs = items
            }
            result.append(SENCEntry(iv: iv, subsamples: subs))
        }
        return result
    }

    private func decryptSample(
        _ sample: inout Data,
        key: Data,
        iv: Data,
        subsamples: [(clear: Int, encrypted: Int)]?
    ) throws {
        var counter = iv
        if counter.count == 8 {
            counter.append(contentsOf: Array(repeating: 0, count: 8))
        }
        guard counter.count == 16, key.count == kCCKeySizeAES128 else {
            throw error("CENC AES-128 key/IV không hợp lệ.")
        }

        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBytes { keyBytes in
            counter.withUnsafeBytes { ivBytes in
                CCCryptorCreateWithMode(
                    CCOperation(kCCDecrypt),
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCPadding(ccNoPadding),
                    ivBytes.baseAddress,
                    keyBytes.baseAddress,
                    key.count,
                    nil,
                    0,
                    0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }
        guard status == kCCSuccess, let cryptor else {
            throw error("Không khởi tạo được AES-CTR.")
        }
        defer { CCCryptorRelease(cryptor) }

        if let subsamples {
            var offset = 0
            for part in subsamples {
                guard offset + part.clear + part.encrypted <= sample.count else {
                    throw error("CENC subsample vượt sample.")
                }
                offset += part.clear
                if part.encrypted > 0 {
                    try cryptRange(&sample, offset: offset, length: part.encrypted, cryptor: cryptor)
                    offset += part.encrypted
                }
            }
        } else {
            try cryptRange(&sample, offset: 0, length: sample.count, cryptor: cryptor)
        }
    }

    private func cryptRange(_ data: inout Data, offset: Int, length: Int, cryptor: CCCryptorRef) throws {
        guard length > 0 else { return }
        var output = [UInt8](repeating: 0, count: length)
        var moved = 0
        let status = data.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { out in
                CCCryptorUpdate(
                    cryptor,
                    input.baseAddress!.advanced(by: offset),
                    length,
                    out.baseAddress,
                    length,
                    &moved
                )
            }
        }
        guard status == kCCSuccess, moved == length else {
            throw error("AES-CTR giải mã sample thất bại.")
        }
        data.replaceSubrange(offset..<(offset + length), with: output)
    }

    private func key(for kid: Data) async throws -> Data {
        let id = base64URL(kid)
        lock.lock()
        if let cached = keys[id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let licenseURL = drm.licenseURL else {
            throw error("ClearKey thiếu license URL.")
        }

        func store(_ candidates: [String: Data]) -> Data? {
            let value = candidates[id] ?? candidates.values.first
            if let value {
                lock.lock()
                keys[id] = value
                lock.unlock()
            }
            return value
        }

        var get = URLRequest(url: licenseURL)
        get.httpMethod = "GET"
        get.timeoutInterval = 15
        headers.forEach { get.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let (data, response) = try? await session.data(for: get),
           let http = response as? HTTPURLResponse,
           200..<300 ~= http.statusCode,
           let candidates = try? ClearKeyContentKeySession.parseJWK(data),
           let value = store(candidates) {
            return value
        }

        var post = URLRequest(url: licenseURL)
        post.httpMethod = "POST"
        post.timeoutInterval = 15
        headers.forEach { post.setValue($0.value, forHTTPHeaderField: $0.key) }
        post.setValue("application/json", forHTTPHeaderField: "Content-Type")
        post.setValue("application/json", forHTTPHeaderField: "Accept")
        post.httpBody = try JSONSerialization.data(withJSONObject: [
            "kids": [base64URL(kid)],
            "type": "temporary"
        ])

        let (data, response) = try await session.data(for: post)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let candidates = try? ClearKeyContentKeySession.parseJWK(data),
              let value = store(candidates) else {
            throw error("ClearKey license không trả về KID/KEY hợp lệ.")
        }
        return value
    }

    private func singleKID() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard keys.count == 1 else { return nil }
        return keys.keys.first.flatMap(ClearKeyContentKeySession.decodeKeyID)
    }

    private func sanitizeInitialization(_ data: Data) -> Data {
        var result = data
        rewriteProtectedSampleEntries(&result)

        // Samples are decrypted before AVPlayer sees them. Keep byte offsets
        // unchanged, but stop the decoded sample entry from advertising CENC.
        // Re-typing sinf as free makes AVFoundation ignore the protection
        // wrapper without rebuilding the enclosing stsd box.
        rewriteProtectionContainers(&result)
        return result
    }

    private func rewriteProtectedSampleEntries(_ data: inout Data) {
        let protectedTypes: Set<String> = ["encv", "enca"]
        guard data.count >= 12 else { return }

        for index in 4..<(data.count - 3) {
            let start = index - 4
            let type = String(
                data: data.subdata(in: index..<(index + 4)),
                encoding: .ascii
            ) ?? ""
            guard protectedTypes.contains(type),
                  let box = boxAt(data, cursor: start, limit: data.count) else {
                continue
            }

            let newType = clearSampleEntryType(data, box)
            let bytes = Array(newType.utf8)
            if bytes.count == 4 {
                data.replaceSubrange((box.offset + 4)..<(box.offset + 8), with: bytes)
            }
        }
    }

    private func clearSampleEntryType(_ data: Data, _ box: Box) -> String {
        if let frma = findRawBox(type: "frma", in: data, range: box.contentStart..<box.end),
           frma.contentStart + 4 <= frma.end {
            return String(
                data: data.subdata(in: frma.contentStart..<(frma.contentStart + 4)),
                encoding: .ascii
            ) ?? (box.type == "enca" ? "mp4a" : "avc1")
        }
        return box.type == "enca" ? "mp4a" : "avc1"
    }

    private func rewriteAllBoxTypes(_ data: inout Data, from: String, to: String) {
        let source = Array(from.utf8)
        let target = Array(to.utf8)
        guard source.count == 4 else { return }
        if data.count < 8 { return }
        for i in 4..<(data.count - 3) where data[i] == source[0] &&
            data[i + 1] == source[1] && data[i + 2] == source[2] && data[i + 3] == source[3] {
            data.replaceSubrange(i..<(i + 4), with: target)
        }
    }

    private func rewriteProtectionContainers(_ data: inout Data) {
        let type = Array("sinf".utf8)
        let replacement = Array("free".utf8)
        guard data.count >= 12 else { return }

        for i in 4..<(data.count - 3) where
            data[i] == type[0] && data[i + 1] == type[1] &&
            data[i + 2] == type[2] && data[i + 3] == type[3] {
            data.replaceSubrange(i..<(i + 4), with: replacement)
        }
    }

    private func findTopLevelBox(_ type: String, in data: Data) -> Box? {
        var cursor = 0
        while let box = boxAt(data, cursor: cursor, limit: data.count) {
            if box.type == type { return box }
            cursor = box.end
            if cursor >= data.count { break }
        }
        return nil
    }

    private func childBoxes(_ data: Data, parent: Box) -> [Box] {
        var result: [Box] = []
        var cursor = parent.contentStart
        while let box = boxAt(data, cursor: cursor, limit: parent.end) {
            result.append(box)
            cursor = box.end
            if cursor >= parent.end { break }
        }
        return result
    }

    private func findRawBox(type: String, in data: Data, range: Range<Int>) -> Box? {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
        let bytes = Array(type.utf8)
        guard bytes.count == 4 else { return nil }
        var index = range.lowerBound + 4
        while index + 4 <= range.upperBound {
            if data[index] == bytes[0] && data[index + 1] == bytes[1] &&
                data[index + 2] == bytes[2] && data[index + 3] == bytes[3] {
                let start = index - 4
                if let box = boxAt(data, cursor: start, limit: range.upperBound), box.type == type {
                    return box
                }
            }
            index += 1
        }
        return nil
    }

    private func parseTrackID(_ data: Data, tkhd: Box) -> UInt32? {
        let version = data[tkhd.offset + 8]
        let offset = version == 1 ? tkhd.offset + 28 : tkhd.offset + 20
        guard offset + 4 <= tkhd.end else { return nil }
        return readUInt32(data, offset)
    }

    private func boxAt(_ data: Data, cursor: Int, limit: Int) -> Box? {
        guard cursor >= 0, cursor + 8 <= limit else { return nil }
        let size32 = Int(readUInt32(data, cursor))
        let type = String(data: data.subdata(in: (cursor + 4)..<(cursor + 8)), encoding: .ascii) ?? ""
        if size32 == 0 {
            return Box(offset: cursor, size: limit - cursor, header: 8, type: type)
        }
        if size32 == 1 {
            guard cursor + 16 <= limit else { return nil }
            let size = Int(readUInt64(data, cursor + 8))
            guard size >= 16, cursor + size <= limit else { return nil }
            return Box(offset: cursor, size: size, header: 16, type: type)
        }
        guard size32 >= 8, cursor + size32 <= limit else { return nil }
        return Box(offset: cursor, size: size32, header: 8, type: type)
    }

    private func fullBoxFlags(_ data: Data, _ box: Box) -> UInt32 {
        (UInt32(data[box.offset + 9]) << 16) |
        (UInt32(data[box.offset + 10]) << 8) |
        UInt32(data[box.offset + 11])
    }

    private func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24) |
        (UInt32(data[offset + 1]) << 16) |
        (UInt32(data[offset + 2]) << 8) |
        UInt32(data[offset + 3])
    }

    private func readUInt64(_ data: Data, _ offset: Int) -> UInt64 {
        (UInt64(readUInt32(data, offset)) << 32) | UInt64(readUInt32(data, offset + 4))
    }

    private func readInt32(_ data: Data, _ offset: Int) -> Int32 {
        Int32(bitPattern: readUInt32(data, offset))
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func error(_ description: String) -> NSError {
        NSError(domain: "NM7CENC", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
