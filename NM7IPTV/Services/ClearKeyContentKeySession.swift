import AVFoundation
import Foundation

final class ClearKeyContentKeySession: NSObject, AVContentKeySessionDelegate {
    private let drm: DRMInfo
    private let headers: [String: String]
    private let session = URLSession(configuration: .ephemeral)
    private let onError: (String) -> Void

    init(drm: DRMInfo, headers: [String: String], onError: @escaping (String) -> Void) {
        self.drm = drm
        self.headers = headers
        self.onError = onError
        super.init()
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let keyID = Self.keyID(for: keyRequest, preferred: self.localPairs.keys.first.flatMap(Self.decodeKeyID))
                let keyData = try await self.obtainKeyData(keyID: keyID)
                keyRequest.processContentKeyResponse(
                    AVContentKeyResponse(clearKeyData: keyData, initializationVector: nil)
                )
            } catch {
                keyRequest.processContentKeyResponseError(error)
                self.onError("ClearKey DRM không lấy được khóa: \(error.localizedDescription)")
            }
        }
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        contentKeySession(session, didProvide: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession,
                           shouldRetryContentKeyRequest keyRequest: AVContentKeyRequest,
                           reason retryReason: AVContentKeyRequest.RetryReason) -> Bool {
        true
    }

    func contentKeySession(_ session: AVContentKeySession,
                           didProvidePersistableContentKeyRequest keyRequest: AVPersistableContentKeyRequest) {
        keyRequest.processContentKeyResponseError(
            NSError(domain: "NM7ClearKey", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "ClearKey không dùng persistable content key."])
        )
    }

    private var localPairs: [String: Data] { Self.parsePairs(drm.licenseValue) }

    private func obtainKeyData(keyID: Data?) async throws -> Data {
        if let keyID, let local = localPairs[keyID.base64URLEncodedString] { return local }
        if localPairs.count == 1, let only = localPairs.values.first { return only }
        guard let licenseURL = drm.licenseURL else {
            throw NSError(domain: "NM7ClearKey", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "ClearKey thiếu KID/KEY hoặc license URL."])
        }
        if let direct = try? await requestLicense(url: licenseURL, keyID: keyID, method: "GET"),
           let key = direct.first?.value {
            return key
        }
        guard let keyID else {
            throw NSError(domain: "NM7ClearKey", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "License ClearKey yêu cầu KID nhưng iOS không đọc được KID."])
        }
        let result = try await requestLicense(url: licenseURL, keyID: keyID, method: "POST")
        guard let key = result.first?.value else {
            throw NSError(domain: "NM7ClearKey", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "License server không trả về ClearKey JWK hợp lệ."])
        }
        return key
    }

    private func requestLicense(url: URL, keyID: Data?, method: String) async throws -> [String: Data] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if method == "POST" {
            guard let keyID else { return [:] }
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "kids": [keyID.base64URLEncodedString], "type": "temporary"
            ])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "NM7ClearKey", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "ClearKey license HTTP không thành công."])
        }
        return try Self.parseJWK(data)
    }

    static func parsePairs(_ value: String) -> [String: Data] {
        var pairs: [String: Data] = [:]
        for part in value.split(separator: ",") {
            let fields = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard fields.count == 2, let kid = decodeKeyID(fields[0]), let key = decodeKey(fields[1]) else { continue }
            pairs[kid.base64URLEncodedString] = key
        }
        return pairs
    }

    static func parseJWK(_ data: Data) throws -> [String: Data] {
        let object = try JSONSerialization.jsonObject(with: data)
        let list: [[String: Any]]
        if let root = object as? [String: Any], let keys = root["keys"] as? [[String: Any]] {
            list = keys
        } else if let single = object as? [String: Any] {
            list = [single]
        } else {
            return [:]
        }
        var result: [String: Data] = [:]
        for item in list {
            guard let kid = item["kid"] as? String, let k = item["k"] as? String,
                  let kidData = decodeKeyID(kid), let keyData = decodeKey(k) else { continue }
            result[kidData.base64URLEncodedString] = keyData
        }
        return result
    }

    static func keyID(for request: AVContentKeyRequest, preferred: Data?) -> Data? {
        if let preferred { return preferred }
        if let identifier = request.identifier {
            if let data = identifier as? Data, data.count == 16 { return data }
            if let url = identifier as? URL { return decodeKeyID(url.absoluteString) }
            if let string = identifier as? String { return decodeKeyID(string) }
        }
        if let data = request.initializationData { return firstPSSHKeyID(data) }
        return nil
    }

    static func decodeKeyID(_ value: String) -> Data? {
        let clean = value.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "skd://", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count == 32, clean.allSatisfy({ $0.isHexDigit }) {
            var bytes = [UInt8]()
            var index = clean.startIndex
            for _ in 0..<16 {
                let next = clean.index(index, offsetBy: 2)
                guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
                bytes.append(byte)
                index = next
            }
            return Data(bytes)
        }
        return base64URLDecode(clean)
    }

    static func decodeKey(_ value: String) -> Data? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count == 32, clean.allSatisfy({ $0.isHexDigit }) {
            var bytes = [UInt8]()
            var index = clean.startIndex
            for _ in 0..<16 {
                let next = clean.index(index, offsetBy: 2)
                guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
                bytes.append(byte)
                index = next
            }
            return Data(bytes)
        }
        return base64URLDecode(clean)
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var string = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while string.count % 4 != 0 { string.append("=") }
        return Data(base64Encoded: string)
    }

    private static func firstPSSHKeyID(_ data: Data) -> Data? {
        var offset = 0
        while offset + 32 <= data.count {
            let size = Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            guard size >= 32, offset + size <= data.count else { break }
            let type = String(data: data.subdata(in: offset + 4..<offset + 8), encoding: .ascii) ?? ""
            if type == "pssh", data[offset + 8] == 1 {
                let count = Int(data[offset + 28]) << 24 | Int(data[offset + 29]) << 16 | Int(data[offset + 30]) << 8 | Int(data[offset + 31])
                if count > 0, offset + 48 <= data.count {
                    return data.subdata(in: offset + 32..<offset + 48)
                }
            }
            offset += size
        }
        return nil
    }
}

private extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
