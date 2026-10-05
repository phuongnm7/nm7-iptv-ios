import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { proxy in
            let metrics = NM7Theme.Metrics.resolve(
                width: proxy.size.width,
                isPad: NM7DeviceProfile.isPad && horizontalSizeClass != .compact
            )

            ZStack {
                NM7BackgroundView()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if model.isLoading && model.channels.isEmpty {
                            loadingView
                        } else if model.visibleChannels.isEmpty {
                            emptyView
                        } else {
                            rows(metrics: metrics)
                        }
                    }
                    .padding(.leading, metrics.contentLeading)
                    .padding(.trailing, metrics.contentTrailing)
                    .padding(.top, 2)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
                .refreshable { await model.reload() }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
        .contentShape(Rectangle())
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Đang tải danh sách kênh…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 120)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tv.slash")
                .font(.system(size: 42, weight: .bold))
            Text("Không có kênh")
                .font(.headline)
            Text("Thử tải lại playlist.")
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 120)
    }

    private func rows(metrics: NM7Theme.Metrics) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               model.selectedGroup == "Tất cả",
               model.section != .favorites,
               model.section != .recent {
                ForEach(model.groups, id: \.self) { group in
                    row(
                        title: group,
                        channels: model.channels.filter { $0.group == group },
                        metrics: metrics
                    )
                }
            } else {
                row(
                    title: model.selectedGroup == "Tất cả" ? model.section.rawValue : model.selectedGroup,
                    channels: model.visibleChannels,
                    metrics: metrics
                )
            }
        }
    }

    private func row(title: String, channels: [Channel], metrics: NM7Theme.Metrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .frame(height: metrics.groupHeaderHeight, alignment: .leading)
                .padding(.top, 3)
                .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(channels) { channel in
                        ChannelCardView(
                            channel: channel,
                            isFavorite: model.libraryStore.favoriteIDs.contains(channel.id),
                            isPlaying: model.selectedChannel?.id == channel.id,
                            metrics: metrics,
                            onPlay: { model.play(channel) },
                            onFavorite: { model.toggleFavorite(channel) }
                        )
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 18)
            }
            .frame(height: metrics.rowHeight)
        }
    }
}
