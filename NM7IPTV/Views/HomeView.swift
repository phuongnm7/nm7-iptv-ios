import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppViewModel
    let onOpenMenu: () -> Void

    @FocusState private var focusedChannelID: String?
    @State private var focusRow = 0
    @State private var focusColumn = 0

    var body: some View {
        GeometryReader { proxy in
            let metrics = NM7Theme.Metrics.resolve(
                width: proxy.size.width,
                isPad: NM7DeviceProfile.isPad,
                height: proxy.size.height
            )

            ZStack(alignment: .topLeading) {
                NM7BackgroundView()

                ScrollViewReader { verticalProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if model.isLoading && model.channels.isEmpty {
                                loadingView
                            } else if model.visibleChannels.isEmpty {
                                emptyView
                            } else {
                                rows(
                                    metrics: metrics,
                                    verticalProxy: verticalProxy
                                )
                            }
                        }
                        .padding(.leading, metrics.contentLeading)
                        .padding(.trailing, metrics.contentTrailing)
                        .padding(.top, metrics.topPadding)
                        .padding(.bottom, 18)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        await model.reload()
                    }
                }

                Button(action: onOpenMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(
                            .system(
                                size: NM7DeviceProfile.isPad ? 22 : 20,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            .black.opacity(0.30),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .padding(.leading, NM7DeviceProfile.isPad ? 12 : 8)
                .padding(.top, 7)
                .accessibilityLabel("Mở menu")
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .focusable()
            .onMoveCommand { direction in
                move(direction)
            }
            .onAppear {
                scheduleFocus()
            }
            .onChange(of: model.channels.count) { _ in
                resetFocus()
            }
            .onChange(of: model.section) { _ in
                resetFocus()
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
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

    private func rows(
        metrics: NM7Theme.Metrics,
        verticalProxy: ScrollViewProxy
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(
                Array(displayedGroups.enumerated()),
                id: .element
            ) { rowIndex, group in
                channelRow(
                    group: group,
                    channels: channels(for: group),
                    rowIndex: rowIndex,
                    metrics: metrics,
                    verticalProxy: verticalProxy
                )
            }
        }
    }

    private func channelRow(
        group: String,
        channels: [Channel],
        rowIndex: Int,
        metrics: NM7Theme.Metrics,
        verticalProxy: ScrollViewProxy
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group)
                .font(
                    .system(
                        size: metrics.groupHeaderFontSize,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .frame(
                    height: metrics.groupHeaderHeight,
                    alignment: .leading
                )
                .padding(.top, 3)
                .padding(.bottom, 4)
                .id("group-(rowIndex)")

            ScrollViewReader { horizontalProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: metrics.cardSpacing) {
                        ForEach(channels) { channel in
                            ChannelCardView(
                                channel: channel,
                                focusedChannelID: $focusedChannelID,
                                isFavorite: model.libraryStore.favoriteIDs.contains(
                                    channel.id
                                ),
                                isPlaying: model.selectedChannel?.id == channel.id,
                                metrics: metrics,
                                onPlay: {
                                    model.play(channel)
                                },
                                onFavorite: {
                                    model.toggleFavorite(channel)
                                }
                            )
                            .id(channel.id)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 18)
                }
                .frame(height: metrics.rowHeight)
                .onChange(of: focusedChannelID) { id in
                    guard let id,
                          channels.contains(where: { $0.id == id }) else {
                        return
                    }

                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.12)) {
                            horizontalProxy.scrollTo(
                                id,
                                anchor: .center
                            )
                            verticalProxy.scrollTo(
                                "group-(rowIndex)",
                                anchor: .center
                            )
                        }
                    }
                }
            }
        }
    }

    private var displayedGroups: [String] {
        if model.searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
           model.selectedGroup == "Tất cả",
           model.section != .favorites,
           model.section != .recent {
            return model.groups
        }

        return [
            model.selectedGroup == "Tất cả"
                ? model.section.rawValue
                : model.selectedGroup
        ]
    }

    private func channels(for group: String) -> [Channel] {
        let filteredMode =
            model.section == .favorites ||
            model.section == .recent ||
            !model.searchText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ||
            model.selectedGroup != "Tất cả"

        if filteredMode {
            return model.visibleChannels.filter {
                $0.group == group
            }
        }

        return model.channels.filter {
            $0.group == group
        }
    }

    private func currentChannels() -> [Channel] {
        guard !displayedGroups.isEmpty else {
            return []
        }

        let rowIndex = min(
            max(0, focusRow),
            displayedGroups.count - 1
        )

        return channels(for: displayedGroups[rowIndex])
    }

    private func resetFocus() {
        guard !displayedGroups.isEmpty else {
            focusedChannelID = nil
            return
        }

        focusRow = min(
            max(0, focusRow),
            displayedGroups.count - 1
        )

        let current = currentChannels()
        focusColumn = min(
            max(0, focusColumn),
            max(0, current.count - 1)
        )

        if let channel = current[safe: focusColumn] {
            focusedChannelID = channel.id
        }
    }

    private func scheduleFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            resetFocus()
        }
    }

    private func move(_ direction: MoveCommandDirection) {
        guard !displayedGroups.isEmpty else {
            return
        }

        switch direction {
        case .left:
            if focusColumn == 0 {
                onOpenMenu()
                return
            }
            focusColumn -= 1

        case .right:
            let current = currentChannels()
            guard !current.isEmpty else {
                return
            }
            focusColumn = min(
                focusColumn + 1,
                current.count - 1
            )

        case .up:
            guard focusRow > 0 else {
                return
            }
            focusRow -= 1
            focusColumn = min(
                focusColumn,
                max(0, currentChannels().count - 1)
            )

        case .down:
            guard focusRow < displayedGroups.count - 1 else {
                return
            }
            focusRow += 1
            focusColumn = min(
                focusColumn,
                max(0, currentChannels().count - 1)
            )

        @unknown default:
            return
        }

        resetFocus()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
