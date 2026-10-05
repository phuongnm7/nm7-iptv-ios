import SwiftUI
import UIKit

struct NM7BackgroundView: View {
    @State private var image: UIImage?
    @State private var loaded = false

    private static let remoteURLs: [URL] = [
        URL(string: "https://nm7-tv-web.phuongnm7-iptv.workers.dev/assets/nm7-default-background.webp")!,
        URL(string: "https://raw.githubusercontent.com/phuongnm7/nm7-tv-web/main/assets/nm7-default-background.webp")!
    ]

    private static var cacheURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("nm7-web-background.webp")
    }

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
        .task {
            await load()
        }
    }

    private func load() async {
        guard !loaded else { return }
        loaded = true

        if let cached = try? Data(contentsOf: Self.cacheURL),
           let cachedImage = UIImage(data: cached) {
            image = cachedImage
        } else if let url = Bundle.main.url(
            forResource: "nm7_default_background_new",
            withExtension: "webp"
        ), let bundled = UIImage(contentsOfFile: url.path) {
            image = bundled
        } else {
            image = UIImage(named: "nm7_default_background_new")
        }

        for url in Self.remoteURLs {
            do {
                var request = URLRequest(url: url, timeoutInterval: 12)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("image/webp,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      200..<300 ~= http.statusCode,
                      data.count > 1024,
                      let downloaded = UIImage(data: data) else {
                    continue
                }
                try? data.write(to: Self.cacheURL, options: .atomic)
                await MainActor.run {
                    image = downloaded
                }
                return
            } catch {
                continue
            }
        }
    }
}
