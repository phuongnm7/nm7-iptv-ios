import SwiftUI
import UIKit

struct ChannelCardView: View {
    let channel: Channel
    @FocusState.Binding var focusedChannelID: String?
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
                    Circle()
                        .fill(.clear)

                    ChannelLogoView(
                        channel: channel,
                        diameter: metrics.logoDiameter
                    )

                    if focused || isPlaying {
                        Circle()
                            .stroke(
                                focused ? NM7Theme.accent : NM7Theme.accent.opacity(0.85),
                                lineWidth: focused ? 4 : 2
                            )
                            .frame(
                                width: focused ? metrics.logoDiameter + 12 : metrics.logoDiameter + 4,
                                height: focused ? metrics.logoDiameter + 12 : metrics.logoDiameter + 4
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: metrics.cardHeight - 18)

                Text(channel.name)
                    .font(.system(size: 11, weight: focused ? .bold : .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
            }
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(focused ? NM7Theme.accent.opacity(0.12) : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        focused ? NM7Theme.accent : .clear,
                        lineWidth: focused ? 3 : 0
                    )
            }
        }
        .buttonStyle(.plain)
        .focused($focusedChannelID, equals: channel.id)
        .focused($focused)
        .scaleEffect(focused ? 1.06 : 1)
        .animation(.easeOut(duration: 0.12), value: focused)
        .contextMenu {
            Button(
                isFavorite ? "Bỏ Yêu thích" : "Thêm vào Yêu thích",
                systemImage: isFavorite ? "star.slash" : "star"
            ) {
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
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: max(10, diameter - 2),
                        height: max(10, diameter - 2)
                    )
            } else {
                Image(systemName: failed ? "tv.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: diameter * 0.42, weight: .bold))
                    .foregroundStyle(NM7Theme.accent.opacity(0.88))
            }
        }
        .frame(width: diameter, height: diameter)
        .task(id: channel.id) {
            data = await ChannelLogoStore.shared.imageData(for: channel)
            failed = data == nil
        }
    }
}
