import AVKit
import SwiftUI

struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppViewModel
    let initialChannel: Channel
    @State private var current: Channel
    @State private var group: String
    @StateObject private var channelPlayer = ChannelPlayer()

    init(model: AppViewModel, initialChannel: Channel) {
        self.model = model
        self.initialChannel = initialChannel
        _current = State(initialValue: initialChannel)
        _group = State(initialValue: initialChannel.group)
    }

    private var groupChannels: [Channel] {
        model.channels.filter { $0.group == group }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let landscape = geometry.size.width > geometry.size.height
                Group {
                    if landscape {
                        HStack(spacing: 0) {
                            video
                            channelPanel.frame(width: min(360, geometry.size.width * 0.34))
                        }
                    } else {
                        VStack(spacing: 0) {
                            video.frame(height: geometry.size.width * 9 / 16)
                            channelPanel
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle(current.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Đóng") { dismiss() },
                trailing: HStack(spacing: 16) {
                    VoiceSearchButton { transcript in
                        if let channel = model.bestVoiceMatch(for: transcript) { play(channel) }
                        else { channelPlayer.showError("Không tìm thấy kênh “\(transcript)”.") }
                    }
                    Button {
                        model.toggleFavorite(current)
                    } label: {
                        Image(systemName: model.libraryStore.favoriteIDs.contains(current.id) ? "star.fill" : "star")
                    }
                }
            )
        }
        .onAppear { play(current) }
        .onDisappear { channelPlayer.stop() }
        .alert("Không phát được kênh", isPresented: Binding(
            get: { channelPlayer.errorMessage != nil },
            set: { if !$0 { channelPlayer.errorMessage = nil } }
        )) {
            Button("Thử lại") { play(current) }
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(channelPlayer.errorMessage ?? "")
        }
    }

    private var video: some View {
        VideoPlayer(player: channelPlayer.player)
            .background(Color.black)
            .overlay {
                if channelPlayer.isLoading {
                    ProgressView("Đang mở \(current.name)…")
                        .padding(16)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .overlay(alignment: .bottom) {
                HStack {
                    Button { changeChannel(by: -1) } label: {
                        Label("Kênh trước", systemImage: "backward.end.fill")
                    }
                    Spacer()
                    Button { changeChannel(by: 1) } label: {
                        Label("Kênh sau", systemImage: "forward.end.fill")
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .padding()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 50).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    changeChannel(by: value.translation.width < 0 ? 1 : -1)
                }
            )
            .ignoresSafeArea(edges: .horizontal)
    }

    private var channelPanel: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(model.groups.dropFirst(), id: \.self) { name in
                        Button(name) { group = name }
                            .buttonStyle(.borderedProminent)
                            .tint(group == name ? .cyan : .gray.opacity(0.35))
                    }
                }.padding(.horizontal)
            }
            List(groupChannels) { channel in
                Button { play(channel) } label: {
                    HStack {
                        AsyncImage(url: channel.logoURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { Image(systemName: "tv") }
                        .frame(width: 52, height: 34)
                        Text(channel.name).lineLimit(1)
                        Spacer()
                        if channel.id == current.id {
                            Image(systemName: "waveform").foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color.black.opacity(0.94))
    }

    private func changeChannel(by offset: Int) {
        let list = groupChannels
        guard !list.isEmpty, let index = list.firstIndex(where: { $0.id == current.id }) else { return }
        let target = (index + offset + list.count) % list.count
        play(list[target])
    }

    private func play(_ channel: Channel) {
        current = channel
        group = channel.group
        model.libraryStore.addRecent(channel)
        channelPlayer.play(channel)
    }
}
