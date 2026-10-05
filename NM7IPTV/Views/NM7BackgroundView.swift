import SwiftUI
import UIKit

struct NM7BackgroundView: View {
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    NM7Theme.navy
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .clipped()
        .onAppear {
            // Android TV 1.0.69 uses drawable/nm7_default_background_new.
            image = UIImage(named: "nm7_default_background_new")
        }
    }
}
