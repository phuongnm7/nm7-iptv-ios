import SwiftUI

enum NM7Theme {
    static let navy = Color(red: 7 / 255, green: 17 / 255, blue: 31 / 255)
    static let surface = Color(red: 14 / 255, green: 28 / 255, blue: 46 / 255)
    static let surfaceAlt = Color(red: 20 / 255, green: 38 / 255, blue: 60 / 255)
    static let textPrimary = Color(red: 245 / 255, green: 248 / 255, blue: 252 / 255)
    static let textSecondary = Color(red: 159 / 255, green: 179 / 255, blue: 200 / 255)
    static let accent = Color(red: 55 / 255, green: 214 / 255, blue: 166 / 255)
    static let accentDark = Color(red: 27 / 255, green: 167 / 255, blue: 126 / 255)
    static let warning = Color(red: 255 / 255, green: 189 / 255, blue: 89 / 255)

    struct Metrics {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let logoDiameter: CGFloat
        let rowHeight: CGFloat
        let groupHeaderHeight: CGFloat
        let groupHeaderFontSize: CGFloat
        let cardSpacing: CGFloat
        let contentLeading: CGFloat
        let contentTrailing: CGFloat
        let topPadding: CGFloat

        static func resolve(width: CGFloat, isPad: Bool, height: CGFloat) -> Metrics {
            if isPad {
                let compact = min(width, height) < 700
                return .init(
                    cardWidth: compact ? 126 : 138,
                    cardHeight: compact ? 72 : 76,
                    logoDiameter: compact ? 50 : 54,
                    rowHeight: compact ? 76 : 80,
                    groupHeaderHeight: compact ? 32 : 34,
                    groupHeaderFontSize: compact ? 17 : 18,
                    cardSpacing: 4,
                    contentLeading: compact ? 14 : 22,
                    contentTrailing: 18,
                    topPadding: 2
                )
            }

            let compact = width < 390
            return .init(
                cardWidth: compact ? 104 : min(126, width * 0.30),
                cardHeight: 70,
                logoDiameter: compact ? 46 : 50,
                rowHeight: 74,
                groupHeaderHeight: 32,
                groupHeaderFontSize: 17,
                cardSpacing: 4,
                contentLeading: 10,
                contentTrailing: 10,
                topPadding: 2
            )
        }
    }
}
