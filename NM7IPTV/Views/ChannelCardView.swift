import SwiftUI

struct ChannelCardView: View {
    let channel: Channel
    let isFavorite: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(16 / 9, contentMode: .fit)
                    AsyncImage(url: channel.logoURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "play.rectangle.fill")
                            .font(.largeTitle).foregroundStyle(.cyan.opacity(0.7))
                    }
                    .padding(12)
                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .yellow : .white)
                            .padding(8)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(5)
                }
                Text(channel.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Phát \(channel.name)")
    }
}
