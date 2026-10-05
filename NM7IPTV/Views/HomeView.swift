import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppViewModel
    private let accent = Color(red: 0.22, green: 0.84, blue: 0.96)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.01, green: 0.02, blue: 0.04),
                    Color(red: 0.03, green: 0.07, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    groupBar

                    if model.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Đang tải danh sách kênh…").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 90)
                    } else if model.visibleChannels.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tv.slash").font(.system(size: 44))
                            Text("Không có kênh").font(.headline)
                            Text("Thử đổi nhóm, nguồn hoặc tải lại playlist.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 90)
                    } else {
                        rows
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.reload() }
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NM7 TV").font(.system(size: 34, weight: .heavy))
                Text("(model.channels.count) kênh • (model.sourceStore.activeSource.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("YouTube") { model.openYouTube() }
                .buttonStyle(.bordered)
        }
    }

    private var groupBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                groupPill("Tất cả")
                ForEach(model.groups, id: \.self) { group in
                    groupPill(group)
                }
            }
        }
    }

    private func groupPill(_ group: String) -> some View {
        Button {
            model.selectedGroup = group
        } label: {
            Text(group)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(model.selectedGroup == group ? .black : .primary)
                .background(
                    model.selectedGroup == group ? accent : Color.white.opacity(0.09),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var rows: some View {
        Group {
            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               model.selectedGroup == "Tất cả",
               model.section != .favorites,
               model.section != .recent {
                ForEach(model.groups, id: \.self) { group in
                    row(group, channels: model.channels.filter { $0.group == group })
                }
            } else {
                row(
                    model.selectedGroup == "Tất cả" ? model.section.rawValue : model.selectedGroup,
                    channels: model.visibleChannels
                )
            }
        }
    }

    private func row(_ title: String, channels: [Channel]) -> some View {
        ChannelRowView(
            title: title,
            channels: channels,
            accent: accent,
            isFavorite: { model.libraryStore.favoriteIDs.contains($0.id) },
            onPlay: { model.play($0) },
            onFavorite: { model.toggleFavorite($0) }
        )
    }
}

private struct ChannelRowView: View {
    let title: String
    let channels: [Channel]
    let accent: Color
    let isFavorite: (Channel) -> Bool
    let onPlay: (Channel) -> Void
    let onFavorite: (Channel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.title3.weight(.bold))
                Text("(channels.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(channels) { channel in
                        ChannelCardView(
                            channel: channel,
                            isFavorite: isFavorite(channel),
                            accent: accent,
                            onPlay: { onPlay(channel) },
                            onFavorite: { onFavorite(channel) }
                        )
                    }
                }
            }
        }
    }
}
