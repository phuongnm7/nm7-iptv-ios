import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        TabView {
            HomeView(model: model)
                .tabItem { Label("Kênh", systemImage: "tv") }
            SourcesView(model: model)
                .tabItem { Label("Nguồn", systemImage: "link") }
            AboutView()
                .tabItem { Label("Thông tin", systemImage: "info.circle") }
        }
        .tint(.cyan)
        .fullScreenCover(item: $model.selectedChannel) { channel in
            PlayerScreen(model: model, initialChannel: channel)
        }
    }
}
