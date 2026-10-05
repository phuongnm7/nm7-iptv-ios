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
            // Exact Android TV 1.0.69 resource: drawable/nm7_default_background_new.webp.
            // Load from the bundle explicitly so this does not depend on asset-catalog lookup.
            if let url = Bundle.main.url(forResource: "nm7_default_background_new", withExtension: "webp") {
                image = UIImage(contentsOfFile: url.path)
            }
            if image == nil {
                image = UIImage(named: "nm7_default_background_new")
            }
        }
    }
}
