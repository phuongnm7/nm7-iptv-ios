import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 230, ideal: 265, max: 310)
        } detail: {
            switch model.section {
            case .sources:
                SourcesView(model: model)
            case .settings:
                SettingsView(model: model)
            default:
                HomeView(model: model)
            }
        }
        .tint(Color(red: 0.22, green: 0.84, blue: 0.96))
        .fullScreenCover(item: $model.selectedChannel) { channel in
            PlayerScreen(model: model, initialChannel: channel)
        }
    }
}
