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
        let contentLeading: CGFloat
        let contentTrailing: CGFloat

        static func resolve(width: CGFloat, isPad: Bool) -> Metrics {
            if isPad {
                return .init(
                    cardWidth: 138,
                    cardHeight: 76,
                    logoDiameter: 54,
                    rowHeight: 80,
                    groupHeaderHeight: 34,
                    contentLeading: 22,
                    contentTrailing: 18
                )
            }

            return .init(
                cardWidth: 138,
                cardHeight: 76,
                logoDiameter: 54,
                rowHeight: 80,
                groupHeaderHeight: 34,
                contentLeading: 14,
                contentTrailing: 14
            )
        }
    }
}
