import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppViewModel
    private let columns = [GridItem(.adaptive(minimum: 145, maximum: 220), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Picker("Danh sách", selection: $model.filter) {
                    ForEach(AppViewModel.Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.groups, id: \.self) { group in
                            Button(group) { model.selectedGroup = group }
                                .buttonStyle(GroupButtonStyle(selected: model.selectedGroup == group))
                        }
                    }.padding(.horizontal)
                }

                if model.isLoading {
                    Spacer()
                    ProgressView("Đang tải danh sách kênh…")
                    Spacer()
                } else if model.visibleChannels.isEmpty {
                    ContentUnavailableView("Không có kênh", systemImage: "tv.slash",
                                           description: Text(model.errorMessage ?? "Thử chọn nhóm hoặc nguồn khác."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.visibleChannels) { channel in
                                ChannelCardView(
                                    channel: channel,
                                    isFavorite: model.libraryStore.favoriteIDs.contains(channel.id),
                                    onPlay: { model.play(channel) },
                                    onFavorite: { model.toggleFavorite(channel) }
                                )
                            }
                        }.padding(12)
                    }.refreshable { await model.reload() }
                }
            }
            .navigationTitle("NM7 IPTV")
            .searchable(text: $model.searchText, prompt: "Tìm kênh")
            .navigationBarItems(trailing:
                Button { Task { await model.reload() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            )
            .alert("Lỗi", isPresented: Binding(
                get: { model.errorMessage != nil && !model.channels.isEmpty },
                set: { if !$0 { model.errorMessage = nil } }
            )) { Button("Đóng", role: .cancel) {} } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

private struct GroupButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.cyan : Color.secondary.opacity(0.2))
            .foregroundStyle(selected ? .black : .primary)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
