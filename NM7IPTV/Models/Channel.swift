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
    var signedURLExpirationDate: Date? {
        guard let components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: {
                  ["expires", "expiry", "exp"].contains($0.name.lowercased())
              })?.value,
              let value = Double(raw),
              value >= 1_000_000_000 else { return nil }

        let seconds = value >= 100_000_000_000 ? value / 1_000 : value
        return Date(timeIntervalSince1970: seconds)
    }
    func hasExpiredSignedURL(now: Date = Date()) -> Bool {
        guard let expiration = signedURLExpirationDate else { return false }
        return expiration <= now
    }
    var referrer: String? { header(named: "Referer") }
    var isHLS: Bool {
        let url = streamURL.absoluteString.lowercased()
        return url.contains(".m3u8") || options.contains { $0.lowercased().contains("manifest_type=hls") }
    }
    var isDASH: Bool {
        let url = streamURL.absoluteString.lowercased()
        if url.contains(".mpd") {
            return true
        }
        if options.contains(where: {
            $0.lowercased().contains("manifest_type=mpd") ||
            $0.lowercased().contains("manifest_type=dash")
        }) {
            return true
        }

        // Some TV360/VTVcab entries intentionally hide the MPD behind a
        // redirect/wrapper URL. When DRM metadata says ClearKey/Widevine and
        // the URL is not already an HLS resource, route it through the DASH
        // engine so the wrapper can be resolved to its actual MPD.
        return isLikelyDRM && !isHLS
    }
    var isLikelyDRM: Bool {
        options.contains { $0.lowercased().contains("license") || $0.lowercased().contains("drm") }
    }

    /// Raw IPTV/MPEG-TS feeds should use LibVLC on iOS. AVPlayer is best
    /// reserved for HLS/fMP4; many sports providers use extensionless HTTP
    /// endpoints, so classification cannot depend only on ".ts".
    var prefersVLC: Bool {
        guard !isDASH, !isHLS,
              let scheme = streamURL.scheme?.lowercased(),
              ["http", "https", "rtsp", "rtsps", "rtmp", "rtmps", "udp", "srt"].contains(scheme)
        else {
            return false
        }

        let path = streamURL.path.lowercased()
        if [".mp4", ".m4v", ".mov"].contains(where: { path.hasSuffix($0) }) {
            return false
        }

        return true
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
        var value = "\(name)|\(url.absoluteString)"
        for key in headers.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            value += "|\(key)=\(headers[key] ?? "")"
        }
        value += "|" + options.joined(separator: "|")
        return Data(value.utf8).base64EncodedString()
    }
}
