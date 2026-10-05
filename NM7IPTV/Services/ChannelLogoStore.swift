import Foundation
import CryptoKit

actor ChannelLogoStore {
    static let shared = ChannelLogoStore()

    private var memory: [String: Data] = [:]
    private let memoryLimit = 96
    private let cacheDirectory: URL
    private let session: URLSession

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheDirectory = base.appendingPathComponent("NM7ChannelLogos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    func imageData(for channel: Channel) async -> Data? {
        let candidates = ChannelLogoResolver.candidates(for: channel)
        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            if let data = memory[candidate] { return data }
            let url = cacheURL(for: candidate)
            if let data = try? Data(contentsOf: url), !data.isEmpty, data.count <= 8 * 1024 * 1024 {
                putMemory(data, for: candidate)
                return data
            }
        }

        for candidate in candidates {
            guard let url = URL(string: candidate),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { continue }

            var request = URLRequest(url: url, timeoutInterval: 8)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1 NM7-TV-iOS/1.0.69",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue(
                "image/png,image/jpeg,image/webp,image/svg+xml;q=0.9,image/*;q=0.8,*/*;q=0.5",
                forHTTPHeaderField: "Accept"
            )

            for (key, value) in channel.httpHeaders {
                guard !key.contains("\r"), !key.contains("\n"),
                      !value.contains("\r"), !value.contains("\n"),
                      key.caseInsensitiveCompare("Host") != .orderedSame,
                      key.caseInsensitiveCompare("Content-Length") != .orderedSame else { continue }
                request.setValue(value, forHTTPHeaderField: key)
            }

            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode,
                  !data.isEmpty,
                  data.count <= 8 * 1024 * 1024 else { continue }

            let preview = String(data: data.prefix(32), encoding: .utf8)?.lowercased() ?? ""
            if preview.contains("<svg") || preview.contains("<?xml") { continue }

            putMemory(data, for: candidate)
            try? data.write(to: cacheURL(for: candidate), options: .atomic)

            if let primary = candidates.first, primary != candidate {
                putMemory(data, for: primary)
                try? data.write(to: cacheURL(for: primary), options: .atomic)
            }
            return data
        }

        return nil
    }

    private func putMemory(_ data: Data, for key: String) {
        memory[key] = data
        while memory.count > memoryLimit {
            if let first = memory.keys.first { memory.removeValue(forKey: first) }
        }
    }

    private func cacheURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(name + ".img")
    }
}