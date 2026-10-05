import Foundation

struct Channel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let group: String
    let tvgID: String
    let logoURL: URL?
    let streamURL: URL
    let httpHeaders: [String: String]
    let options: [String]

    var userAgent: String? { header(named: "User-Agent") }
    var referrer: String? { header(named: "Referer") }
    var isHLS: Bool {
        let url = streamURL.absoluteString.lowercased()
        return url.contains(".m3u8") || options.contains { $0.lowercased().contains("manifest_type=hls") }
    }
    var isDASH: Bool {
        let url = streamURL.absoluteString.lowercased()
        return url.contains(".mpd") || options.contains { $0.lowercased().contains("manifest_type=mpd") }
    }
    var isLikelyDRM: Bool {
        options.contains { $0.lowercased().contains("license") || $0.lowercased().contains("drm") }
    }

    init(
        name: String,
        group: String,
        tvgID: String = "",
        logoURL: URL?,
        streamURL: URL,
        httpHeaders: [String: String] = [:],
        options: [String] = []
    ) {
        self.name = name.isEmpty ? "Kênh không tên" : name
        self.group = group.isEmpty ? "Chưa phân nhóm" : group
        self.tvgID = tvgID
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.httpHeaders = httpHeaders
        self.options = options
        self.id = Self.stableID(name: self.name, url: streamURL, headers: httpHeaders, options: options)
    }

    private func header(named name: String) -> String? {
        httpHeaders.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private static func stableID(name: String, url: URL, headers: [String: String], options: [String]) -> String {
        var value = "(name)|(url.absoluteString)"
        for key in headers.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            value += "|(key)=(headers[key] ?? "")"
        }
        value += "|" + options.joined(separator: "|")
        return Data(value.utf8).base64EncodedString()
    }
}
