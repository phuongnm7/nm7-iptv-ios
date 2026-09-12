import Foundation

enum M3UParser {
    static func parse(_ text: String) -> [Channel] {
        let lines = text.components(separatedBy: .newlines)
        var result: [Channel] = []
        var metadata: String?
        var headers: [String: String] = [:]

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("#EXTINF:") {
                metadata = line
                headers.removeAll(keepingCapacity: true)
            } else if line.hasPrefix("#EXTVLCOPT:") {
                let option = String(line.dropFirst("#EXTVLCOPT:".count))
                let parts = option.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 { headers[parts[0].lowercased()] = parts[1] }
            } else if !line.hasPrefix("#"), let info = metadata, let url = URL(string: line) {
                let name = info.split(separator: ",", maxSplits: 1).last.map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Kênh"
                let group = attribute("group-title", in: info) ?? "Chưa phân nhóm"
                let logo = attribute("tvg-logo", in: info).flatMap(URL.init(string:))
                result.append(Channel(
                    name: name,
                    group: group,
                    logoURL: logo,
                    streamURL: url,
                    userAgent: headers["http-user-agent"] ?? headers["user-agent"],
                    referrer: headers["http-referrer"] ?? headers["referrer"]
                ))
                metadata = nil
                headers.removeAll(keepingCapacity: true)
            }
        }
        return result
    }

    private static func attribute(_ key: String, in line: String) -> String? {
        let pattern = #"(?:^|\s)"# + NSRegularExpression.escapedPattern(for: key) + #"="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }
}
