import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppViewModel
    @State private var showMenu = false

    var body: some View {
        NavigationStack {
            detail
                .navigationBarHidden(true)
                .ignoresSafeArea()
        }
        .tint(NM7Theme.accent)
        .fullScreenCover(item: $model.selectedChannel) { channel in
            PlayerScreen(model: model, initialChannel: channel)
        }
        .sheet(isPresented: $showMenu) {
            NavigationStack {
                SidebarView(model: model)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    guard value.startLocation.x < 28,
                          value.translation.width > 90 else { return }
                    showMenu = true
                }
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch model.section {
        case .sources:
            SourcesView(model: model)
        case .settings:
            SettingsView(model: model)
        default:
            HomeView(model: model)
        }
    }
}
