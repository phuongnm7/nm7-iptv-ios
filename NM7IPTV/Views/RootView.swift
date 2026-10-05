import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        Group {
            if NM7DeviceProfile.isPad {
                iPadRoot
            } else {
                iPhoneRoot
            }
        }
        .tint(NM7Theme.accent)
        .fullScreenCover(item: $model.selectedChannel) { channel in
            PlayerScreen(model: model, initialChannel: channel)
        }
    }

    private var iPadRoot: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 310)
        } detail: {
            NavigationStack { detail }
        }
    }

    private var iPhoneRoot: some View {
        NavigationStack {
            detail
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MobileBottomBar(model: model)
                }
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
            HomeView(model: model)
        }
    }
}