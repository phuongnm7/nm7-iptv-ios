import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        ZStack {
            NM7BackgroundView()

            List {
                Section {
                    HStack(spacing: 10) {
                        Image(uiImage: NM7Assets.mainLogo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("NM7 TV")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(NM7Theme.textPrimary)
                            Text("1.0.70 • Web UI + DRM fix")
                                .font(.caption)
                                .foregroundStyle(NM7Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 7)
                    .listRowBackground(Color.clear)
                }

                Section {
                    sidebarButton(.home, icon: "house.fill")
                    sidebarButton(.all, icon: "square.grid.2x2.fill")
                    sidebarButton(.television, icon: "tv.fill")
                    sidebarButton(.sports, icon: "sportscourt.fill")
                    sidebarButton(.favorites, icon: "star.fill")
                    sidebarButton(.recent, icon: "clock.fill")
                }

                Section("Tiện ích") {
                    Button { model.openYouTube() } label: {
                        Label("YouTube", systemImage: "play.rectangle.fill")
                    }

                    sidebarButton(.sources, icon: "link")
                    sidebarButton(.settings, icon: "gearshape.fill")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func sidebarButton(_ section: AppViewModel.Section, icon: String) -> some View {
        Button {
            Task { await model.selectSection(section) }
        } label: {
            Label(section.rawValue, systemImage: icon)
                .font(.system(size: 15, weight: section == model.section ? .bold : .medium))
                .foregroundStyle(NM7Theme.textPrimary)
        }
        .listRowBackground(section == model.section ? NM7Theme.accent.opacity(0.18) : Color.clear)
    }
}