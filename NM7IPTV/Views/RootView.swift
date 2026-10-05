import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppViewModel
    @State private var showMenu = false

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = min(
                proxy.size.width * (NM7DeviceProfile.isPad ? 0.34 : 0.86),
                NM7DeviceProfile.isPad ? 380 : 340
            )

            ZStack(alignment: .leading) {
                NavigationStack {
                    detail
                        .navigationBarHidden(true)
                        .ignoresSafeArea()
                }
                .tint(NM7Theme.accent)

                if showMenu {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { closeMenu() }
                        .transition(.opacity)
                        .zIndex(90)

                    SidebarView(
                        model: model,
                        onClose: { closeMenu() }
                    )
                    .frame(width: drawerWidth, height: proxy.size.height)
                    .background(NM7Theme.navy)
                    .shadow(radius: 24)
                    .transition(.move(edge: .leading))
                    .zIndex(100)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeInOut(duration: 0.20), value: showMenu)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let startedAtLeftEdge = value.startLocation.x < 42
                        if startedAtLeftEdge && value.translation.width > 90 {
                            openMenu()
                        } else if showMenu && value.translation.width < -90 {
                            closeMenu()
                        }
                    }
            )
        }
        .fullScreenCover(item: $model.selectedChannel) { channel in
            PlayerScreen(model: model, initialChannel: channel)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.section {
        case .sources:
            SourcesView(model: model)
        case .settings:
            SettingsView(model: model)
        default:
            HomeView(
                model: model,
                onOpenMenu: { openMenu() }
            )
        }
    }

    private func openMenu() {
        showMenu = true
    }

    private func closeMenu() {
        showMenu = false
    }
}
