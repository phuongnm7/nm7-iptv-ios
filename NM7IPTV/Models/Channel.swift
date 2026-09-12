import Foundation

struct Channel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let group: String
    let logoURL: URL?
    let streamURL: URL
    let userAgent: String?
    let referrer: String?

    init(name: String, group: String, logoURL: URL?, streamURL: URL,
         userAgent: String? = nil, referrer: String? = nil) {
        self.name = name
        self.group = group.isEmpty ? "Chưa phân nhóm" : group
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.userAgent = userAgent
        self.referrer = referrer
        self.id = Self.stableID(name: name, url: streamURL)
    }

    private static func stableID(name: String, url: URL) -> String {
        Data((name + "|" + url.absoluteString).utf8).base64EncodedString()
    }
}
