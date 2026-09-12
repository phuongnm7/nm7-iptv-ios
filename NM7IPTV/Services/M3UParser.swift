import Foundation

enum M3UParser {
    static func parse(_ text: String) -> [Channel] {
        let lines = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
        var result: [Channel] = []
        var metadata: String?
        var headers: [String: String] = [:]

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#EXTINF:") {
                metadata = line
                headers.removeAll(keepingCapacity: true)
                continue
            }
            if line.uppercased().hasPrefix("#EXTVLCOPT:") {
                parseVLCOption(String(line.dropFirst("#EXTVLCOPT:".count)), into: &headers)
                continue
            }
            if line.uppercased().hasPrefix("#EXTHTTP:") {
                parseJSONHeaders(String(line.dropFirst("#EXTHTTP:".count)), into: &headers)
                continue
            }
            guard !line.hasPrefix("#"), let info = metadata else { continue }

            let split = splitURLAndHeaders(line)
            guard let url = URL(string: split.url),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                metadata = nil
                headers.removeAll(keepingCapacity: true)
                continue
            }
            headers.merge(split.headers) { _, inline in inline }
            let name = info.split(separator: ",", maxSplits: 1).last.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Kênh"
            let group = attribute("group-title", in: info) ?? "Chưa phân nhóm"
            let logo = attribute("tvg-logo", in: info).flatMap(URL.init(string:))
            result.append(Channel(
                name: name,
                group: group,
                logoURL: logo,
                streamURL: url,
                httpHeaders: headers
            ))
            metadata = nil
            headers.removeAll(keepingCapacity: true)
        }
        return result
    }

    private static func splitURLAndHeaders(_ line: String) -> (url: String, headers: [String: String]) {
        guard let pipe = line.firstIndex(of: "|") else {
            return (line.trimmingCharacters(in: .whitespacesAndNewlines), [:])
        }
        let url = String(line[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)
        let query = String(line[line.index(after: pipe)...])
        var headers: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = normalizeHeader(parts[0].removingPercentEncoding ?? parts[0])
            let value = parts[1].removingPercentEncoding ?? parts[1]
            if !key.isEmpty, !value.contains("\r"), !value.contains("\n") { headers[key] = value }
        }
        return (url, headers)
    }

    private static func parseVLCOption(_ option: String, into headers: inout [String: String]) {
        let parts = option.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let key = normalizeHeader(parts[0])
        if !key.isEmpty { headers[key] = parts[1] }
    }

    private static func parseJSONHeaders(_ json: String, into headers: inout [String: String]) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (rawKey, rawValue) in object {
            guard let value = rawValue as? String else { continue }
            let key = normalizeHeader(rawKey)
            if !key.isEmpty, !value.contains("\r"), !value.contains("\n") { headers[key] = value }
        }
    }

    private static func normalizeHeader(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "http-user-agent", "user-agent", "useragent": return "User-Agent"
        case "http-referrer", "http-referer", "referrer", "referer": return "Referer"
        case "http-origin", "origin": return "Origin"
        case "http-cookie", "cookie": return "Cookie"
        default:
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.range(of: #"^[!#$%&'*+.^_~0-9A-Za-z-]+$"#, options: .regularExpression) == nil ? "" : value
        }
    }

    private static func attribute(_ key: String, in line: String) -> String? {
        let pattern = #"(?:^|\s)"# + NSRegularExpression.escapedPattern(for: key) + #"="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }
}
