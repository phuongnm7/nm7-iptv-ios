import Foundation
import CommonCrypto

final class CENCResourceProcessor: NSObject, UPlayerMediaResourceProcessor {
    struct TrackInfo {
        let kid: Data
        let ivSize: Int
        let constantIV: Data?
        let defaultSampleSize: Int
        let scheme: String
        let cryptBlock: Int
        let skipBlock: Int
    }

    struct Box {
        let offset: Int
        let size: Int
        let header: Int
        let type: String
        var end: Int { offset + size }
        var contentStart: Int { offset + header }
    }

    struct SENCEntry {
        let iv: Data
        let subsamples: [(clear: Int, encrypted: Int)]?
    }

    struct SENCResult {
        let entries: [SENCEntry]
        let kid: Data
        let ivSize: Int
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
        let parsedKeys: [String: Data]
        if pairs.isEmpty, let data = drm.licenseValue.data(using: .utf8),
           let jwk = try? ClearKeyContentKeySession.parseJWK(data) {
            parsedKeys = jwk.compactMapValues { $0 }
        } else {
            parsedKeys = pairs
        }
        lock.lock()
        for (kidString, key) in parsedKeys {
            if let kid = ClearKeyContentKeySession.decodeKeyID(kidString) {
                keys[base64URL(kid)] = key
            }
        }
        lock.unlock()
    }

    func processMediaData(_ data: Data, sourceURL: URL) async throws -> Data {
        // A SegmentBase representation can point all EXT-X-BYTERANGE entries
        // at one physical MP4 containing moov + many moof boxes. Never return
        // early just because moov exists: the requested byte range may belong
        // to a later encrypted fragment.
        var output = data

        if let moov = findTopLevelBox("moov", in: output) {
            parseTrackEncryption(output, moov: moov)
            output = sanitizeInitialization(output)
        }

        if findTopLevelBox("moof", in: output) != nil {
            output = try await decryptFragments(output)
        }

        return output
    }

    private func parseTrackEncryption(_ data: Data, moov: Box) {
        var trexDefaultSizes: [UInt32: Int] = [:]
        if let mvex = childBoxes(data, parent: moov).first(where: { $0.type == "mvex" }) {
            for trex in childBoxes(data, parent: mvex).filter({ $0.type == "trex" }) {
                guard trex.contentStart + 16 <= trex.end else { continue }
                let trackID = readUInt32(data, trex.contentStart + 4)
                let defaultSampleSize = Int(readUInt32(data, trex.contentStart + 12))
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

            guard parsed.isProtected == 1 else { continue }

            let schemeInfo = parseSchemeInfo(data, trackRange: trak.offset..<trak.end)
            let info = TrackInfo(
                kid: parsed.kid,
                ivSize: parsed.ivSize,
                constantIV: parsed.constantIV,
                defaultSampleSize: trexDefaultSizes[trackID] ?? 0,
                scheme: schemeInfo.scheme,
                cryptBlock: parsed.cryptBlock,
                skipBlock: parsed.skipBlock
            )
            lock.lock()
            tracks[trackID] = info
            lock.unlock()
        }
    }

    /// Parses ISO/IEC 23001-7 TrackEncryptionBox.
    ///
    /// After the 8-byte BMFF header + 4-byte FullBox header, the tenc body is:
    ///   v0: reserved, reserved, isProtected, IVSize, KID[16]
    ///   v1+: reserved, crypt/skip, isProtected, IVSize, KID[16]
    /// Hence isProtected=+14, IVSize=+15, KID=+16 for both versions.
    static func parseTENC(data: Data, offset: Int, size: Int)
        -> (version: Int, isProtected: Int, ivSize: Int, kid: Data, constantIV: Data?, cryptBlock: Int, skipBlock: Int)? {
        guard offset >= 0, size >= 32, offset + size <= data.count,
              data[offset + 4] == 0x74,
              data[offset + 5] == 0x65,
              data[offset + 6] == 0x6E,
              data[offset + 7] == 0x63 else {
            return nil
        }

        let version = Int(data[offset + 8])
        guard version == 0 || version >= 1 else { return nil }

        let patternOffset = offset + 13
        let isProtectedOffset = offset + 14
        let ivSizeOffset = offset + 15
        let kidOffset = offset + 16
        guard kidOffset + 16 <= offset + size else { return nil }

        let pattern = Int(data[patternOffset])
        let isProtected = Int(data[isProtectedOffset])
        let ivSize = Int(data[ivSizeOffset])
        let cryptBlock = version >= 1 ? ((pattern >> 4) & 0x0F) : 0
        let skipBlock = version >= 1 ? (pattern & 0x0F) : 0
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
            constantIV: constantIV,
            cryptBlock: cryptBlock,
            skipBlock: skipBlock
        )
    }
    private func decryptFragments(_ source: Data) async throws -> Data {
        let moofs = topLevelBoxes("moof", in: source)
        guard !moofs.isEmpty else { return source }

        var output = source

        for moof in moofs {
            for traf in childBoxes(source, parent: moof).filter({ $0.type == "traf" }) {
                guard let tfhd = childBoxes(source, parent: traf).first(where: { $0.type == "tfhd" }) else {
                    continue
                }

                let truns = childBoxes(source, parent: traf).filter { $0.type == "trun" }
                guard !truns.isEmpty else {
                    throw error("CENC traf thiếu trun.")
                }

                let trackID = readUInt32(source, tfhd.contentStart + 4)
                lock.lock()
                let info = tracks[trackID]
                lock.unlock()

                guard let info else {
                    // Encrypted media must never silently pass through to AVPlayer.
                    // If the init segment has not established tenc state yet, fail
                    // explicitly so the caller can report the real CENC state error.
                    throw error("CENC chưa có track-encryption state cho track (trackID). Hãy tải init segment trước media segment.")
                }

                let tfhdFlags = fullBoxFlags(source, tfhd)
                var tfhdCursor = tfhd.contentStart + 4
                guard tfhdCursor + 4 <= tfhd.end else {
                    throw error("tfhd thiếu track_ID.")
                }
                tfhdCursor += 4

                // base_data_offset_present
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
                } else if (tfhdFlags & 0x020000) != 0 {
                    // default-base-is-moof: offsets are anchored at moof.
                    baseOffset = moof.offset
                } else {
                    // For the SegmentBase/CMAF resources generated by NM7, the
                    // effective fragment base is still the containing moof.
                    baseOffset = moof.offset
                }

                if (tfhdFlags & 0x000002) != 0 {
                    guard tfhdCursor + 4 <= tfhd.end else {
                        throw error("tfhd thiếu sample-description-index.")
                    }
                    tfhdCursor += 4
                }

                var defaultSampleSize = 0
                if (tfhdFlags & 0x000008) != 0 {
                    guard tfhdCursor + 4 <= tfhd.end else {
                        throw error("tfhd thiếu default-sample-duration.")
                    }
                    tfhdCursor += 4
                }
                if (tfhdFlags & 0x000010) != 0 {
                    guard tfhdCursor + 4 <= tfhd.end else {
                        throw error("tfhd thiếu default-sample-size.")
                    }
                    defaultSampleSize = Int(readUInt32(source, tfhdCursor))
                    tfhdCursor += 4
                }
                if (tfhdFlags & 0x000020) != 0 {
                    guard tfhdCursor + 4 <= tfhd.end else {
                        throw error("tfhd thiếu default-sample-flags.")
                    }
                    tfhdCursor += 4
                }

                // A traf may legally contain more than one trun. Keep each run's
                // data offset while sharing one encryption-entry sequence.
                var runs: [(offset: Int, sizes: [Int])] = []
                var fallbackOffset = moof.end

                for trun in truns {
                    let parsed = try parseTRUN(
                        source,
                        box: trun,
                        baseOffset: baseOffset,
                        fallback: fallbackOffset,
                        defaultSampleSize: defaultSampleSize
                    )
                    runs.append(parsed)
                    let runBytes = parsed.sizes.reduce(0, +)
                    guard parsed.offset >= 0,
                          runBytes >= 0,
                          parsed.offset <= Int.max - runBytes else {
                        throw error("CENC trun data range quá lớn.")
                    }
                    fallbackOffset = parsed.offset + runBytes
                }

                let sampleCount = runs.reduce(0) { $0 + $1.sizes.count }
                guard sampleCount > 0 else {
                    throw error("CENC fragment không có sample.")
                }

                let trafChildren = childBoxes(source, parent: traf)
                let encryption: SENCResult

                if let senc = trafChildren.first(where: { $0.type == "senc" }) {
                    encryption = try parseSENC(
                        source,
                        box: senc,
                        defaultKID: info.kid,
                        defaultIVSize: info.ivSize,
                        constantIV: info.constantIV
                    )
                } else if let saiz = trafChildren.first(where: { $0.type == "saiz" }),
                          let saio = trafChildren.first(where: { $0.type == "saio" }) {
                    encryption = SENCResult(
                        entries: try parseAuxiliaryEncryption(
                            source,
                            saiz: saiz,
                            saio: saio,
                            baseOffset: baseOffset,
                            ivSize: info.ivSize,
                            constantIV: info.constantIV,
                            sampleCount: sampleCount
                        ),
                        kid: info.kid,
                        ivSize: info.ivSize
                    )
                } else {
                    throw error("CENC fragment thiếu senc hoặc saiz/saio cho track (trackID).")
                }

                guard encryption.entries.count == sampleCount else {
                    throw error("CENC encryption/sample count không khớp (enc=\(encryption.entries.count), trun=\(sampleCount)).")
                }

                let key = try await key(for: encryption.kid)
                var encryptionIndex = 0

                for run in runs {
                    var sampleOffset = run.offset

                    for size in run.sizes {
                        guard size > 0,
                              sampleOffset >= 0,
                              sampleOffset + size <= output.count else {
                            throw error("CENC sample range không hợp lệ.")
                        }

                        var sample = output.subdata(in: sampleOffset..<(sampleOffset + size))
                        let entry = encryption.entries[encryptionIndex]

                        try decryptSample(
                            &sample,
                            key: key,
                            iv: entry.iv,
                            subsamples: entry.subsamples,
                            scheme: info.scheme,
                            cryptBlock: info.cryptBlock,
                            skipBlock: info.skipBlock
                        )

                        output.replaceSubrange(
                            sampleOffset..<(sampleOffset + size),
                            with: sample
                        )
                        sampleOffset += size
                        encryptionIndex += 1
                    }
                }
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
        var cursor = box.contentStart + 4

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
        var cursor = box.contentStart + 4

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
        var cursor = box.contentStart + 4
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

    private func parseSENC(
        _ data: Data,
        box: Box,
        defaultKID: Data,
        defaultIVSize: Int,
        constantIV: Data?
    ) throws -> SENCResult {
        let flags = fullBoxFlags(data, box)
        var cursor = box.contentStart + 4

        var kid = defaultKID
        var ivSize = defaultIVSize

        // override-track-encryption-parameters.
        // The override fields are: AlgorithmID(3), IVSize(1), KID(16).
        if (flags & 0x000001) != 0 {
            guard cursor + 20 <= box.end else {
                throw error("senc thiếu tham số mã hóa ghi đè.")
            }
            cursor += 3 // AlgorithmID; AES-CTR is the CENC family handled here.
            ivSize = Int(data[cursor])
            cursor += 1
            kid = data.subdata(in: cursor..<(cursor + 16))
            cursor += 16
        }

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

        return SENCResult(entries: result, kid: kid, ivSize: ivSize)
    }

    private func decryptSample(
        _ sample: inout Data,
        key: Data,
        iv: Data,
        subsamples: [(clear: Int, encrypted: Int)]?,
        scheme: String,
        cryptBlock: Int,
        skipBlock: Int
    ) throws {
        if scheme.lowercased() == "cbcs" || scheme.lowercased() == "cbc1" {
            try decryptCBSSample(&sample, key: key, iv: iv, subsamples: subsamples,
                                 cryptBlock: cryptBlock, skipBlock: skipBlock)
            return
        }
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

    private func decryptCBSSample(
        _ sample: inout Data,
        key: Data,
        iv: Data,
        subsamples: [(clear: Int, encrypted: Int)]?,
        cryptBlock: Int,
        skipBlock: Int
    ) throws {
        guard key.count == kCCKeySizeAES128, iv.count == kCCBlockSizeAES128 else {
            throw error("CBCS AES-128 key/IV không hợp lệ.")
        }

        var cursor = 0
        let clearRanges = subsamples ?? [(clear: 0, encrypted: sample.count)]
        var remainingPattern = 0
        var remainingSkip = 0

        func decryptRange(_ offset: Int, _ length: Int,
                          cryptor: inout CCCryptorRef?) throws {
            guard length > 0 else { return }
            let blockSize = kCCBlockSizeAES128
            let full = (length / blockSize) * blockSize
            guard full > 0 else { return }

            if cryptBlock == 0 && skipBlock == 0 {
                if cryptor == nil {
                    cryptor = try makeCBCryptor(key: key, iv: iv)
                }
                try cryptRangeWithCryptor(&sample, offset: offset, length: full, cryptor: cryptor!)
                return
            }

            var pos = 0
            while pos + blockSize <= full {
                if remainingPattern == 0 && remainingSkip == 0 {
                    remainingPattern = cryptBlock
                    remainingSkip = skipBlock
                }

                if remainingPattern > 0 {
                    let blockCount = min(remainingPattern, max(1, (full - pos) / blockSize))
                    if cryptor == nil {
                        cryptor = try makeCBCryptor(key: key, iv: iv)
                    }
                    let bytes = blockCount * blockSize
                    try cryptRangeWithCryptor(&sample, offset: offset + pos,
                                              length: bytes, cryptor: cryptor!)
                    pos += bytes
                    remainingPattern -= blockCount
                }

                if remainingPattern == 0 && remainingSkip > 0 {
                    let blockCount = min(remainingSkip, max(1, (full - pos) / blockSize))
                    pos += blockCount * blockSize
                    remainingSkip -= blockCount
                }
            }
        }

        var cryptor: CCCryptorRef?
        defer {
            if let cryptor { CCCryptorRelease(cryptor) }
        }

        for range in clearRanges {
            guard cursor + range.clear + range.encrypted <= sample.count else {
                throw error("CBCS subsample vượt sample.")
            }
            cursor += range.clear
            try decryptRange(cursor, range.encrypted, cryptor: &cryptor)
            cursor += range.encrypted
        }
    }

    private func makeCBCryptor(key: Data, iv: Data) throws -> CCCryptorRef {
        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                CCCryptorCreateWithMode(
                    CCOperation(kCCDecrypt),
                    CCMode(kCCModeCBC),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCPadding(ccNoPadding),
                    ivBytes.baseAddress,
                    keyBytes.baseAddress,
                    key.count,
                    nil,
                    0,
                    0,
                    0,
                    &cryptor
                )
            }
        }
        guard status == kCCSuccess, let cryptor else {
            throw error("Không khởi tạo được AES-CBC.")
        }
        return cryptor
    }

    private func cryptRangeWithCryptor(
        _ data: inout Data,
        offset: Int,
        length: Int,
        cryptor: CCCryptorRef
    ) throws {
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
            throw error("AES-CBC giải mã sample thất bại.")
        }
        data.replaceSubrange(offset..<(offset + length), with: output)
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
            // Never substitute a different KID when a license contains
            // multiple keys. A single-key response may safely satisfy this KID.
            let value = candidates[id] ?? (candidates.count == 1 ? candidates.values.first : nil)
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

    private func parseSchemeInfo(_ data: Data, trackRange: Range<Int>)
        -> (scheme: String, cryptBlock: Int, skipBlock: Int) {
        guard let schm = findRawBox(type: "schm", in: data, range: trackRange),
              schm.contentStart + 8 <= schm.end else {
            return ("cenc", 0, 0)
        }
        let scheme = String(
            data: data.subdata(in: (schm.contentStart + 4)..<(schm.contentStart + 8)),
            encoding: .ascii
        )?.lowercased() ?? "cenc"
        return (scheme, 0, 0)
    }

    private func topLevelBoxes(_ type: String, in data: Data) -> [Box] {
        var result: [Box] = []
        var cursor = 0
        while let box = boxAt(data, cursor: cursor, limit: data.count) {
            if box.type == type {
                result.append(box)
            }
            cursor = box.end
            if cursor >= data.count { break }
        }
        return result
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
