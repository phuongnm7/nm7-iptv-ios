import SwiftUI

struct ChannelCardView: View {
    let channel: Channel
    let isFavorite: Bool
    let accent: Color
    let onPlay: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onPlay) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 178, height: 100)

                        if let logo = channel.logoURL {
                            AsyncImage(url: logo) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFit().padding(13)
                                } else {
                                    placeholder
                                }
                            }
                            .frame(width: 162, height: 84)
                        } else {
                            placeholder
                        }

                        if channel.isLikelyDRM {
                            Text("DRM")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.65), in: Capsule())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                .padding(7)
                        }
                    }

                    Text(channel.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(width: 178, alignment: .leading)

                    Text(channel.group)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 178, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isFavorite ? .yellow : .white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    private var placeholder: some View {
        Image(systemName: "tv.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(accent.opacity(0.8))
    }
}
