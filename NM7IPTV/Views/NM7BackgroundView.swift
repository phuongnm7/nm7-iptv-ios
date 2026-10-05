import SwiftUI
import UIKit

struct NM7BackgroundView: View {
    @State private var image: UIImage?

    private let overlay = Color(
        red: 7 / 255,
        green: 17 / 255,
        blue: 31 / 255
    ).opacity(0x24 / 255.0)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    NM7Theme.navy
                }
                overlay
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .clipped()
        .onAppear {
            image = UIImage(named: "nm7_default_background")
        }
    }
}
