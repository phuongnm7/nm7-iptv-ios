import Foundation

enum ChannelLogoResolver {
    private static let vtv3 = "https://cdn.hqth.me/logo/thumbs/14.png"
    private static let vtv6 = "https://cdn.hqth.me/logo/thumbs/17.png"
    private static let vtv16 = "https://cdn.hqth.me/logo/thumbs/24.png"
    private static let vtv18 = "https://cdn.hqth.me/logo/thumbs/26.png"

    static func isAffected(_ channel: Channel?) -> Bool {
        index(for: channel) != 0
    }

    static func candidates(for channel: Channel?) -> [String] {
        guard let channel else { return [] }
        var result: [String] = []
        switch index(for: channel) {
        case 3:
            append(&result, vtv3)
            append(&result, "https://assets-vtvcab.gviet.vn/images/hq/posters/_ports_ng_logo_04202212.jpg")
            append(&result, "https://i.ibb.co/tsBYvZ4/onsports-BEARTV.png")
        case 6:
            append(&result, vtv6)
            append(&result, "https://assets-vtvcab.gviet.vn/images/hq/posters/onsportscongmoi1.jpg")
            append(&result, "https://i.ibb.co/Bc8cL7w/onsportplus3-BEARTV.png")
        case 16:
            append(&result, vtv16)
            append(&result, "https://assets-vtvcab.gviet.vn/images/hq/posters/_ootball_-_opyright_by_cab_logo_202212.jpg")
            append(&result, "https://i.ibb.co/vd1LBK7/onfootbal-BEARTV.png")
        case 18:
            append(&result, vtv18)
            append(&result, "https://assets-vtvcab.gviet.vn/images/v2/channel/20220613/2022061306/Logo_ONSPORTSNEWS_150x904_1675158858.webp")
            append(&result, "https://i.ibb.co/PGG1dkn/ONSPORTSNEWS-BEARTV.png")
        default:
            break
        }
        append(&result, channel.logoURL?.absoluteString ?? "")
        return result
    }

    private static func index(for channel: Channel?) -> Int {
        guard let channel,
              normalize(channel.group).replacingOccurrences(of: " ", with: "").contains("vtvcab") else {
            return 0
        }
        let id = normalize(channel.tvgID)
        if id == "vtvcab3hd" { return 3 }
        if id == "vtvcab6hd" { return 6 }
        if id == "vtvcab16hd" { return 16 }
        if id == "vtvcab18hd" { return 18 }

        let name = normalize(channel.name)
        if containsAny(name, ["on sports news", "onsports news", "vtvcab 18", "vtvcab18"]) { return 18 }
        if containsAny(name, ["on sports+", "on sports +", "onsports+", "vtvcab 6", "vtvcab6"]) { return 6 }
        if containsAny(name, ["on football", "onfootball", "vtvcab 16", "vtvcab16"]) { return 16 }
        if containsAny(name, ["on sports", "onsports", "vtvcab 3", "vtvcab3"]) { return 3 }
        return 0
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains(where: value.contains)
    }

    private static func append(_ target: inout [String], _ value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !target.contains(clean) else { return }
        target.append(clean)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}