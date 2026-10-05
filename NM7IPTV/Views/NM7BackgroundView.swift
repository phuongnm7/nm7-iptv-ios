import SwiftUI
import UIKit

struct NM7BackgroundView: View {
    private let overlay = Color(
        red: 7 / 255,
        green: 17 / 255,
        blue: 31 / 255
    ).opacity(0x24 / 255.0)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = exactBackgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    overlay
                } else {
                    NM7Theme.navy
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .clipped()
    }

    private var exactBackgroundImage: UIImage? {
        guard let url = Bundle.main.url(
            forResource: "nm7_default_background_new",
            withExtension: "webp"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
