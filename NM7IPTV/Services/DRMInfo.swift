import Foundation

struct DRMInfo: Equatable {
    enum System: Equatable {
        case none, fairPlay, widevine, playReady, clearKey, unknown
    }

    let system: System
    let licenseURL: URL?
    let certificateURL: URL?
    let licenseHeaders: [String: String]

    var hasDRM: Bool { system != .none }
    var isNativeFairPlay: Bool { system == .fairPlay }

    static func from(options: [String]) -> DRMInfo {
        var system: System = .none
        var license = ""
        var certificate = ""
        var headers: [String: String] = [:]

        for raw in options {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = line.firstIndex(of: "=") else { continue }

            let key = String(line[..<separator])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if key.contains("license_type") {
                let lower = value.lowercased()
                if lower.contains("fairplay") || lower.contains("streamingkeydelivery") ||
                    lower.contains("com.apple") || lower.contains("skd") {
                    system = .fairPlay
                } else if lower.contains("widevine") {
                    system = .widevine
                } else if lower.contains("playready") {
                    system = .playReady
                } else if lower.contains("clearkey") {
                    system = .clearKey
                } else if !value.isEmpty && lower != "none" {
                    system = .unknown
                }
            } else if key.contains("certificate") || key.contains("cert_url") {
                certificate = value
                if system == .none { system = .fairPlay }
            } else if key.contains("license_key") || key.contains("license_url") ||
                        key.hasSuffix(".license") || key == "license" {
                let parts = value.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                license = parts.first ?? ""
                if parts.count > 1 {
                    for field in parts[1].split(separator: "&") {
                        let pair = field.split(separator: "=", maxSplits: 1).map(String.init)
                        guard pair.count == 2 else { continue }
                        headers[pair[0]] = pair[1].removingPercentEncoding ?? pair[1]
                    }
                }
            } else if key.contains("license_headers"),
                      let data = value.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (name, rawValue) in object {
                    if let string = rawValue as? String { headers[name] = string }
                }
            }
        }

        if system == .none && !license.isEmpty { system = .unknown }

        return DRMInfo(
            system: system,
            licenseURL: URL(string: license),
            certificateURL: URL(string: certificate),
            licenseHeaders: sanitize(headers)
        )
    }

    private static func sanitize(_ headers: [String: String]) -> [String: String] {
        headers.filter { key, value in
            !key.contains("\r") && !key.contains("\n") &&
            !value.contains("\r") && !value.contains("\n") &&
            key.caseInsensitiveCompare("Host") != .orderedSame &&
            key.caseInsensitiveCompare("Content-Length") != .orderedSame
        }
    }
}