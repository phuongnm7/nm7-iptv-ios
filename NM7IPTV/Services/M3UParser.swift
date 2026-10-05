import Foundation

enum M3UParser {
    struct Result {
        let channels: [Channel]
        let epgURL: URL?
    }

    static func parse(_ text: String, baseURL: URL? = nil) -> Result {
        let content = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        if content.contains("\0") { return Result(channels: [], epgURL: nil) }

        if content.range(of: #"(?m)^\s*#EXT-X-"#, options: .regularExpression) != nil {
            guard let baseURL else { return Result(channels: [], epgURL: nil) }
            let channel = Channel(
                name: "Luồng HLS",
                group: "Phát trực tiếp",
                tvgID: "",
                logoURL: nil,
                streamURL: baseURL,
                httpHeaders: [:],
                options: ["#KODIPROP:inputstream.adaptive.manifest_type=hls"]
            )
            return Result(channels: [channel], epgURL: nil)
        }

        var metadata: String?
        var groupOverride: String?
        var headers: [String: String] = [:]
        var options: [String] = []
        var epgURL: URL?
        var channels: [Channel] = []
        var seen = Set<String>()

        for raw in content.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.uppercased().hasPrefix("#EXTM3U") {
                if let value = attribute("url-tvg", in: line) ?? attribute("x-tvg-url", in: line) {
                    epgURL = resolveURL(value, baseURL: baseURL)
                }
                continue
            }

            if line.uppercased().hasPrefix("#EXTINF:") {
                metadata = line
                groupOverride = nil
                headers.removeAll(keepingCapacity: true)
                options.removeAll(keepingCapacity: true)
                continue
            }

            if line.uppercased().hasPrefix("#EXTGRP:") {
                groupOverride = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line.uppercased().hasPrefix("#EXTVLCOPT:") {
                let value = String(line.dropFirst("#EXTVLCOPT:".count))
                if !parseVLCOption(value, into: &headers) { options.append(line) }
                continue
            }

            if line.uppercased().hasPrefix("#EXTHTTP:") {
                parseJSONHeaders(String(line.dropFirst("#EXTHTTP:".count)), into: &headers)
                continue
            }

            if line.hasPrefix("#") {
                if metadata != nil { options.append(line) }
                continue
            }

            guard let info = metadata else { continue }
            let split = splitURLAndHeaders(line)

            guard let url = resolveURL(split.url, baseURL: baseURL),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "rtsp", "rtsps", "udp", "rtmp", "rtmps", "srt"].contains(scheme) else {
                metadata = nil
                groupOverride = nil
                headers.removeAll(keepingCapacity: true)
                options.removeAll(keepingCapacity: true)
                continue
            }

            headers.merge(split.headers) { _, incoming in incoming }
            options.append(contentsOf: split.options)

            let name = info.split(separator: ",", maxSplits: 1).last.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Kênh"
            let group = groupOverride ?? attribute("group-title", in: info) ?? "Chưa phân nhóm"
            let tvgID = attribute("tvg-id", in: info) ?? ""
            let logo = attribute("tvg-logo", in: info).flatMap { resolveURL($0, baseURL: baseURL) }

            let channel = Channel(
                name: name,
                group: group,
                tvgID: tvgID,
                logoURL: logo,
                streamURL: url,
                httpHeaders: headers,
                options: options
            )

            if seen.insert(channel.id).inserted {
                channels.append(channel)
            }

            metadata = nil
            groupOverride = nil
            headers.removeAll(keepingCapacity: true)
            options.removeAll(keepingCapacity: true)
        }

        return Result(channels: normalizeForIOS(channels), epgURL: epgURL)
    }

    /// iOS cannot invoke the Widevine CDM used by the "Dự phòng" VTV entries.
    /// The same playlist already contains non-DRM HLS versions for VTV2/3/7/9/10.
    /// Keep those backup entries visible, but make their playback URL point to the
    /// known HLS stream so the iOS app can actually play the backup group.
    static func normalizeForIOS(_ channels: [Channel]) -> [Channel] {
        var result: [Channel] = []
        result.reserveCapacity(channels.count)

        let primaryByName: [String: Channel] = Dictionary(
            channels
                .filter { !$0.isDASH && !$0.isLikelyDRM }
                .map { (backupKey($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for channel in channels {
            let normalizedGroup = normalizeGroup(channel.group)
            guard normalizedGroup == "VTV dự phòng" else {
                result.append(channel)
                continue
            }

            let key = backupKey(channel.name)
            if let primary = primaryByName[key], primary.isHLS {
                let replacement = Channel(
                    name: channel.name,
                    group: "VTV dự phòng",
                    tvgID: channel.tvgID.isEmpty ? primary.tvgID : channel.tvgID,
                    logoURL: channel.logoURL ?? primary.logoURL,
                    streamURL: primary.streamURL,
                    httpHeaders: primary.httpHeaders,
                    options: ["#NM7-IOS-VTV-BACKUP-HLS"]
                )
                result.append(replacement)
            } else {
                // Preserve an unsupported entry rather than silently deleting it.
                result.append(channel)
            }
        }

        return result
    }

    private static func normalizeGroup(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.contains("dự phòng") || normalized.contains("du phong") {
            return "VTV dự phòng"
        }
        return value
    }

    private static func backupKey(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        if let range = normalized.range(of: "vtv") {
            let suffix = normalized[range.upperBound...]
            let number = suffix.prefix { $0.isNumber }
            if !number.isEmpty {
                return "vtv" + number
            }
        }
        return normalized
    }

    private static func parseVLCOption(_ option: String, into headers: inout [String: String]) -> Bool {
        let parts = option.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        switch parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "http-user-agent": headers["User-Agent"] = parts[1]
        case "http-referrer", "http-referer": headers["Referer"] = parts[1]
        case "http-origin": headers["Origin"] = parts[1]
        case "http-cookie": headers["Cookie"] = parts[1]
        default: return false
        }
        return true
    }

    private static func parseJSONHeaders(_ json: String, into headers: inout [String: String]) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (key, value) in object {
            guard let value = value as? String,
                  !key.contains("\r"), !key.contains("\n"),
                  !value.contains("\r"), !value.contains("\n") else { continue }
            headers[key] = value
        }
    }

    private static func splitURLAndHeaders(_ line: String) -> (url: String, headers: [String: String], options: [String]) {
        guard let pipe = line.firstIndex(of: "|") else { return (line, [:], []) }
        let url = String(line[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)
        let query = String(line[line.index(after: pipe)...])
        var result: [String: String] = [:]
        var drmOptions: [String] = []

        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].removingPercentEncoding ?? parts[0]
            let value = parts[1].removingPercentEncoding ?? parts[1]
            guard !key.contains("\r"), !key.contains("\n"),
                  !value.contains("\r"), !value.contains("\n") else { continue }

            switch key.lowercased() {
            case "referrer", "referer": result["Referer"] = value
            case "user-agent", "useragent": result["User-Agent"] = value
            case "origin": result["Origin"] = value
            case "cookie": result["Cookie"] = value
            case "drmscheme", "drm_scheme": drmOptions.append("#KODIPROP:inputstream.adaptive.license_type=\(value)")
            case "drmlicense", "drm_license": drmOptions.append("#KODIPROP:inputstream.adaptive.license_key=\(value)")
            default: result[key] = value
            }
        }
        return (url, result, drmOptions)
    }

    private static func resolveURL(_ value: String, baseURL: URL?) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let absolute = URL(string: clean), absolute.scheme != nil { return absolute }
        return baseURL.flatMap { URL(string: clean, relativeTo: $0)?.absoluteURL }
    }

    private static func attribute(_ key: String, in line: String) -> String? {
        let pattern = #"(?:^|\s)"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }
}