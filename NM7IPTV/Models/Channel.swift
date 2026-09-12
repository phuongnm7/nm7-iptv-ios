import Foundation

struct Channel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let group: String
    let logoURL: URL?
    let streamURL: URL
    let httpHeaders: [String: String]

    var userAgent: String? { header(named: "User-Agent") }
    var referrer: String? { header(named: "Referer") }

    init(name: String, group: String, logoURL: URL?, streamURL: URL,
         httpHeaders: [String: String] = [:]) {
        self.name = name
        self.group = group.isEmpty ? "Chưa phân nhóm" : group
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.httpHeaders = httpHeaders
        self.id = Self.stableID(name: name, url: streamURL)
    }

    private func header(named name: String) -> String? {
        httpHeaders.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private static func stableID(name: String, url: URL) -> String {
        Data((name + "|" + url.absoluteString).utf8).base64EncodedString()
    }
}
