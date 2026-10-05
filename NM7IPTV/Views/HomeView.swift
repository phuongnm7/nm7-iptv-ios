import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        GeometryReader { proxy in
            let metrics = NM7Theme.Metrics.resolve(width: proxy.size.width, isPad: NM7DeviceProfile.isPad)

            ZStack {
                NM7BackgroundView()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header
                        groupBar

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
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
                .refreshable { await model.reload() }
            }
        }
        .navigationTitle(model.section.rawValue)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $model.searchText, prompt: "Tìm kênh")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                VoiceSearchButton { model.openVoiceChannel($0) }
                Button { Task { await model.reload() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(uiImage: NM7Assets.mainLogo)
                .resizable()
                .scaledToFit()
                .frame(width: NM7DeviceProfile.isPad ? 46 : 38, height: NM7DeviceProfile.isPad ? 46 : 38)

            VStack(alignment: .leading, spacing: 1) {
                Text("Danh sách kênh TV")
                    .font(.system(size: NM7DeviceProfile.isPad ? 21 : 18, weight: .heavy))
                    .foregroundStyle(NM7Theme.textPrimary)

                Text("\(model.channels.count) kênh • \(model.sourceStore.activeSource.name)")
                    .font(.system(size: 11))
                    .foregroundStyle(NM7Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button { model.openYouTube() } label: {
                Label("YouTube", systemImage: "play.rectangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, NM7DeviceProfile.isPad ? 14 : 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(NM7Theme.accent)
        }
        .frame(height: NM7DeviceProfile.isPad ? 64 : 56)
        .padding(.top, NM7DeviceProfile.isPad ? 4 : 0)
    }

    private var groupBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                groupPill("Tất cả")
                ForEach(model.groups, id: \.self) { group in groupPill(group) }
            }
            .padding(.bottom, 12)
        }
    }

    private func groupPill(_ group: String) -> some View {
        Button { model.selectedGroup = group } label: {
            Text(group)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .foregroundStyle(model.selectedGroup == group ? NM7Theme.navy : NM7Theme.textPrimary)
                .background(
                    model.selectedGroup == group ? NM7Theme.accent : NM7Theme.surface.opacity(0.92),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().tint(NM7Theme.accent)
            Text("Đang tải danh sách kênh…")
                .font(.subheadline)
                .foregroundStyle(NM7Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tv.slash")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(NM7Theme.accent)
            Text("Không có kênh")
                .font(.headline)
                .foregroundStyle(NM7Theme.textPrimary)
            Text("Thử đổi nhóm, nguồn hoặc tải lại playlist.")
                .font(.subheadline)
                .foregroundStyle(NM7Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
    }

    private func rows(metrics: NM7Theme.Metrics) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               model.selectedGroup == "Tất cả",
               model.section != .favorites,
               model.section != .recent {
                ForEach(model.groups, id: \.self) { group in
                    row(title: group, channels: model.channels.filter { $0.group == group }, metrics: metrics)
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(NM7Theme.textPrimary)
                Text("\(channels.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NM7Theme.textSecondary)
                Spacer()
            }
            .frame(height: metrics.groupHeaderHeight)
            .padding(.top, 8)
            .padding(.bottom, 5)

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
                .padding(.vertical, 3)
                .padding(.trailing, 18)
            }
            .frame(height: metrics.rowHeight)
        }
    }
}