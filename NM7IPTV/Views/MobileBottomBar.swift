import SwiftUI

struct MobileBottomBar: View {
    @ObservedObject var model: AppViewModel
    @State private var showMore = false

    var body: some View {
        HStack(spacing: 0) {
            tab(.home, icon: "house.fill", title: "Trang chính")
            tab(.television, icon: "tv.fill", title: "Truyền hình")
            tab(.sports, icon: "sportscourt.fill", title: "Thể thao")
            tab(.favorites, icon: "star.fill", title: "Yêu thích")

            Button { showMore = true } label: {
                item(
                    icon: "ellipsis",
                    title: "Thêm",
                    active: showMore || model.section == .sources || model.section == .settings || model.section == .recent
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 5)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(NM7Theme.accent.opacity(0.35)).frame(height: 0.5)
        }
        .sheet(isPresented: $showMore) {
            NavigationStack {
                List {
                    Button {
                        showMore = false
                        Task { await model.selectSection(.recent) }
                    } label: { Label("Gần đây", systemImage: "clock.fill") }

                    Button {
                        showMore = false
                        model.openYouTube()
                    } label: { Label("YouTube", systemImage: "play.rectangle.fill") }

                    Button {
                        showMore = false
                        Task { await model.selectSection(.sources) }
                    } label: { Label("Nguồn IPTV", systemImage: "link") }

                    Button {
                        showMore = false
                        Task { await model.selectSection(.settings) }
                    } label: { Label("Tùy chọn ứng dụng", systemImage: "gearshape.fill") }
                }
                .navigationTitle("Tiện ích")
            }
            .presentationDetents([.medium])
        }
    }

    private func tab(_ section: AppViewModel.Section, icon: String, title: String) -> some View {
        Button {
            Task { await model.selectSection(section) }
        } label: {
            item(icon: icon, title: title, active: model.section == section)
        }
        .buttonStyle(.plain)
    }

    private func item(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: active ? .bold : .medium))
                .foregroundStyle(active ? NM7Theme.accent : NM7Theme.textSecondary)
            Text(title)
                .font(.system(size: 10, weight: active ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(active ? NM7Theme.textPrimary : NM7Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
    }
}