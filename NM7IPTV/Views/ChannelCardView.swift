import SwiftUI
import UIKit

struct ChannelCardView: View {
    let channel: Channel
    let isFavorite: Bool
    let isPlaying: Bool
    let metrics: NM7Theme.Metrics
    let onPlay: () -> Void
    let onFavorite: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: onPlay) {
            VStack(spacing: 0) {
                ZStack {
                    if focused && NM7DeviceProfile.isPad {
                        Circle()
                            .fill(Color(red: 64 / 255, green: 169 / 255, blue: 255 / 255).opacity(0.33))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .stroke(Color(red: 47 / 255, green: 155 / 255, blue: 255 / 255), lineWidth: 5)
                            }
                    }

                    Circle()
                        .stroke(
                            focused ? .white : (isPlaying ? NM7Theme.accent : .clear),
                            lineWidth: 2
                        )
                        .frame(width: 54, height: 54)

                    ChannelLogoView(channel: channel, diameter: metrics.logoDiameter)
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(44, metrics.cardHeight - 18))

                Text(channel.name)
                    .font(.system(size: NM7DeviceProfile.isPad ? 11 : 10.5, weight: focused ? .bold : .regular))
                    .foregroundStyle(NM7Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
            }
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
        }
        .buttonStyle(.plain)
        .focused($focused)
        .scaleEffect(focused && NM7DeviceProfile.isPad ? 1.12 : 1)
        .animation(.easeOut(duration: 0.12), value: focused)
        .contextMenu {
            Button(isFavorite ? "Bỏ Yêu thích" : "Thêm vào Yêu thích", systemImage: isFavorite ? "star.slash" : "star") {
                onFavorite()
            }
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            if !NM7DeviceProfile.isPad { onFavorite() }
        }
        .accessibilityLabel(channel.name)
        .accessibilityHint(isPlaying ? "Đang phát" : "Mở kênh")
    }
}

private struct ChannelLogoView: View {
    let channel: Channel
    let diameter: CGFloat

    @State private var data: Data?
    @State private var failed = false

    var body: some View {
        ZStack {
            Circle()
                .fill(NM7Theme.surface.opacity(0.9))
                .overlay(Circle().stroke(NM7Theme.textSecondary.opacity(0.16), lineWidth: 1))

            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: max(10, diameter - 4), height: max(10, diameter - 4))
                    .clipShape(Circle())
            } else {
                Image(systemName: failed ? "tv.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: diameter * 0.42, weight: .bold))
                    .foregroundStyle(NM7Theme.accent.opacity(0.82))
            }
        }
        .frame(width: diameter, height: diameter)
        .task(id: channel.id) {
            data = await ChannelLogoStore.shared.imageData(for: channel)
            failed = data == nil
        }
    }
}