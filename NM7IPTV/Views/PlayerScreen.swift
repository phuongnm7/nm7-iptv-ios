import AVKit
import SwiftUI

struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppViewModel
    let initialChannel: Channel
    @State private var current: Channel
    @State private var player = AVPlayer()
    @State private var group: String

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
                        HStack(spacing: 0) { video; channelPanel.frame(width: min(360, geometry.size.width * 0.34)) }
                    } else {
                        VStack(spacing: 0) { video.frame(height: geometry.size.width * 9 / 16); channelPanel }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle(current.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.toggleFavorite(current)
                    } label: {
                        Image(systemName: model.libraryStore.favoriteIDs.contains(current.id) ? "star.fill" : "star")
                    }
                }
            }
        }
        .onAppear { play(current) }
        .onDisappear { player.pause(); player.replaceCurrentItem(with: nil) }
    }

    private var video: some View {
        VideoPlayer(player: player)
            .background(Color.black)
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
                        if channel.id == current.id { Image(systemName: "waveform").foregroundStyle(.cyan) }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color.black.opacity(0.94))
    }

    private func play(_ channel: Channel) {
        current = channel
        group = channel.group
        model.libraryStore.addRecent(channel)
        let asset = AVURLAsset(url: channel.streamURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": channel.userAgent ?? "NM7-IPTV-iOS/0.1.0",
                "Referer": channel.referrer ?? ""
            ]
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 12
        player.replaceCurrentItem(with: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.play()
    }
}
