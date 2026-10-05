import SwiftUI
import UIKit

struct NM7BackgroundView: View {
    private static let sourceURL = URL(string:
        "https://raw.githubusercontent.com/phuongnm7/nm7-tv-android/v1.0.69-fast-vtvcab-logo-16/app/src/main/res/drawable/nm7_default_background.jpg"
    )!
    @State private var image: UIImage?
    private let overlay = Color(red: 7 / 255, green: 17 / 255, blue: 31 / 255).opacity(0x24 / 255.0)

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
        .task { await loadBackground() }
    }

    private func loadBackground() async {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("nm7_android_1_0_69_background.jpg")
        if let cached = try? Data(contentsOf: cacheURL), let image = UIImage(data: cached) {
            await MainActor.run { self.image = image }
            return
        }
        do {
            let request = URLRequest(url: Self.sourceURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode, let image = UIImage(data: data) else { return }
            try? data.write(to: cacheURL, options: .atomic)
            await MainActor.run { self.image = image }
        } catch {}
    }
}
