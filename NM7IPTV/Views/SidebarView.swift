import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppViewModel

    private let accent = Color(red: 0.22, green: 0.84, blue: 0.96)

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text("NM7 TV")
                        .font(.system(size: 28, weight: .heavy))
                    Text("1.0.69 • Android baseline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
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
                Button {
                    model.openYouTube()
                } label: {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                }

                sidebarButton(.sources, icon: "link")
                sidebarButton(.settings, icon: "gearshape.fill")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.01, green: 0.02, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private func sidebarButton(_ section: AppViewModel.Section, icon: String) -> some View {
        Button {
            Task { await model.selectSection(section) }
        } label: {
            Label(section.rawValue, systemImage: icon)
                .font(.system(size: 15, weight: section == model.section ? .bold : .medium))
        }
        .listRowBackground(
            section == model.section
                ? accent.opacity(0.18)
                : Color.clear
        )
    }
}
