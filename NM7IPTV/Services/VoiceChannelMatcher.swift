import Foundation

enum VoiceChannelMatcher {
    static func bestMatch(for transcript: String, channels: [Channel]) -> Channel? {
        var query = normalize(transcript)
        ["mở kênh", "xem kênh", "phát kênh", "chuyển sang", "mở", "xem", "phát"].forEach {
            query = query.replacingOccurrences(of: normalize($0), with: " ")
        }
        query = query.split(separator: " ").joined(separator: " ")
        guard !query.isEmpty else { return nil }

        if let exact = channels.first(where: { normalize($0.name) == query }) { return exact }
        if let contained = channels.first(where: { query.contains(normalize($0.name)) }) { return contained }
        return channels
            .map { ($0, similarity(query, normalize($0.name))) }
            .filter { $0.1 >= 0.55 }
            .max(by: { $0.1 < $1.1 })?.0
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs.contains(rhs) || rhs.contains(lhs) { return 0.9 }
        let left = Set(lhs.split(separator: " "))
        let right = Set(rhs.split(separator: " "))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }
}
