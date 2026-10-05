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
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                if landscape && geometry.size.width >= 700 {
                    HStack(spacing: 0) {
                        videoPane
                        channelPanel.frame(width: min(380, geometry.size.width * 0.34))
                    }
                } else {
                    VStack(spacing: 0) {
                        videoPane.frame(height: min(geometry.size.width * 9 / 16, 420))
                        channelPanel
                    }
                }

                topBar
            }
        }
        .statusBarHidden(true)
        .onAppear { play(current) }
        .onDisappear { channelPlayer.stop() }
        .alert("Không phát được kênh", isPresented: Binding(
            get: { channelPlayer.errorMessage != nil },
            set: { if !$0 { channelPlayer.errorMessage = nil } }
        )) {
            Button("Thử lại") { play(current) }
            Button("Đóng", role: .cancel) { dismiss() }
        } message: {
            Text(channelPlayer.errorMessage ?? "")
        }
    }

    private var videoPane: some View {
        ZStack {
            VideoPlayer(player: channelPlayer.player)
                .opacity(channelPlayer.engine == .avPlayer ? 1 : 0)
                .allowsHitTesting(channelPlayer.engine == .avPlayer)

            VLCVideoSurface(channelPlayer: channelPlayer)
                .opacity(channelPlayer.engine == .vlc ? 1 : 0)

            if channelPlayer.isLoading || !channelPlayer.statusMessage.isEmpty {
                VStack(spacing: 8) {
                    if channelPlayer.isLoading { ProgressView() }
                    if !channelPlayer.statusMessage.isEmpty {
                        Text(channelPlayer.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(16)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: 360)
            }
        }
        .background(Color.black)
        .overlay(alignment: .bottom) {
            HStack(spacing: 14) {
                playerButton("backward.end.fill") { changeChannel(by: -1) }
                Spacer()
                Text(current.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                playerButton("forward.end.fill") { changeChannel(by: 1) }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(.black.opacity(0.58))
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    changeChannel(by: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var channelPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.groups, id: \.self) { name in
                        Button(name) { group = name }
                            .buttonStyle(.borderedProminent)
                            .tint(group == name ? .cyan : .gray.opacity(0.38))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            List(groupChannels) { channel in
                Button { play(channel) } label: {
                    HStack(spacing: 10) {
                        AsyncImage(url: channel.logoURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit()
                            } else {
                                Image(systemName: "tv")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .frame(width: 54, height: 34)

                        Text(channel.name).lineLimit(1)
                        Spacer()

                        if channel.id == current.id {
                            Image(systemName: "waveform")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
                .listRowBackground(
                    channel.id == current.id
                    ? Color.cyan.opacity(0.12)
                    : Color.clear
                )
            }
            .listStyle(.plain)
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.06))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(current.name).font(.headline).lineLimit(1)
                Text(current.group).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VoiceSearchButton { transcript in
                if let match = model.bestVoiceMatch(for: transcript) {
                    play(match)
                }
            }

            Button { model.toggleFavorite(current) } label: {
                Image(systemName: model.libraryStore.favoriteIDs.contains(current.id) ? "star.fill" : "star")
            }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.75))
        }
        .padding(12)
    }

    private func playerButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.headline)
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.bordered)
    }

    private func changeChannel(by offset: Int) {
        let list = groupChannels
        guard let index = list.firstIndex(where: { $0.id == current.id }), !list.isEmpty else { return }
        play(list[(index + offset + list.count) % list.count])
    }

    private func play(_ channel: Channel) {
        current = channel
        group = channel.group
        model.libraryStore.addRecent(channel)
        channelPlayer.play(channel)
    }
}
