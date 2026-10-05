import SwiftUI
import UIKit

struct NM7BackgroundView: View {
    var body: some View {
        Group {
            if let image = exactBackgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                NM7Theme.navy
            }
        }
        .ignoresSafeArea()
    }

    private var exactBackgroundImage: UIImage? {
        if let url = Bundle.main.url(forResource: "nm7_default_background_new", withExtension: "webp") {
            return UIImage(contentsOfFile: url.path)
        }
        if let url = Bundle.main.url(
            forResource: "nm7_default_background_new",
            withExtension: "webp",
            subdirectory: "Resources"
        ) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}