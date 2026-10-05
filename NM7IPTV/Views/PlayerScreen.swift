import AVKit
import SwiftUI
import UIKit

struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppViewModel
    let initialChannel: Channel

    @State private var current: Channel
    @State private var group: String
    @State private var showControls = true
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
            let split = NM7DeviceProfile.isPad && landscape && geometry.size.width >= 700

            ZStack {
                Color.black.ignoresSafeArea()

                if split {
                    HStack(spacing: 0) {
                        videoPane
                        channelPanel.frame(width: min(380, max(300, geometry.size.width * 0.32)))
                    }
                } else {
                    VStack(spacing: 0) {
                        videoPane
                            .frame(
                                height: NM7DeviceProfile.isPhone
                                    ? min(geometry.size.width * 9 / 16, 245)
                                    : min(geometry.size.width * 9 / 16, 440)
                            )
                        channelPanel
                    }
                }

                if showControls {
                    topBar
                }
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

            if channelPlayer.isLoading {
                ProgressView()
                    .tint(NM7Theme.accent)
                    .padding(14)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
            }

            if showControls {
                HStack {
                    playerButton("backward.end.fill") { changeChannel(by: -1) }
                    Spacer()
                    playerButton(
                        channelPlayer.engine == .avPlayer && channelPlayer.player.timeControlStatus == .playing ? "pause.fill" : "play.fill"
                    ) {
                        channelPlayer.togglePlayPause()
                    }
                    Spacer()
                    playerButton("forward.end.fill") { changeChannel(by: 1) }
                }
                .padding(.horizontal, NM7DeviceProfile.isPhone ? 12 : 20)
                .padding(.bottom, NM7DeviceProfile.isPhone ? 10 : 16)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .gesture(globalGesture)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.18)) { showControls.toggle() }
        }
    }

    private var channelPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.groups, id: \.self) { name in
                        Button(name) { group = name }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(group == name ? NM7Theme.navy : NM7Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(group == name ? NM7Theme.accent : NM7Theme.surface, in: Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            List(groupChannels) { channel in
                Button { play(channel) } label: {
                    HStack(spacing: 10) {
                        ChannelLogoMini(channel: channel)
                        Text(channel.name)
                            .lineLimit(1)
                            .foregroundStyle(NM7Theme.textPrimary)
                        Spacer()
                        if channel.id == current.id {
                            Image(systemName: "waveform")
                                .foregroundStyle(NM7Theme.accent)
                        }
                    }
                }
                .listRowBackground(
                    channel.id == current.id ? NM7Theme.accent.opacity(0.12) : Color.clear
                )
            }
            .listStyle(.plain)
        }
        .background(NM7Theme.navy)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(current.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Text(current.group)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            if !NM7DeviceProfile.isPhone {
                VoiceSearchButton { transcript in
                    if let match = model.bestVoiceMatch(for: transcript) { play(match) }
                }
            }

            Button { model.toggleFavorite(current) } label: {
                Image(systemName: model.libraryStore.favoriteIDs.contains(current.id) ? "star.fill" : "star")
            }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.75))
        }
        .padding(NM7DeviceProfile.isPhone ? 8 : 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var globalGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    changeChannel(by: value.translation.width < 0 ? 1 : -1)
                } else if NM7DeviceProfile.isPhone && value.translation.height > 90 {
                    dismiss()
                }
            }
    }

    private func playerButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.headline)
                .frame(
                    width: NM7DeviceProfile.isPhone ? 40 : 46,
                    height: NM7DeviceProfile.isPhone ? 40 : 46
                )
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.85))
    }

    private func changeChannel(by offset: Int) {
        let list = groupChannels
        guard !list.isEmpty, let index = list.firstIndex(where: { $0.id == current.id }) else { return }
        play(list[(index + offset + list.count) % list.count])
    }

    private func play(_ channel: Channel) {
        current = channel
        group = channel.group
        model.libraryStore.addRecent(channel)
        channelPlayer.play(channel)
    }
}

private struct ChannelLogoMini: View {
    let channel: Channel
    @State private var data: Data?

    var body: some View {
        ZStack {
            Circle().fill(NM7Theme.surface)

            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
                    .padding(3)
            } else {
                Image(systemName: "tv.fill").foregroundStyle(NM7Theme.accent)
            }
        }
        .frame(width: 44, height: 44)
        .task(id: channel.id) {
            data = await ChannelLogoStore.shared.imageData(for: channel)
        }
    }
}