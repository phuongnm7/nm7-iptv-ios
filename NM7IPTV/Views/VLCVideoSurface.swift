import SwiftUI
import UIKit

struct VLCVideoSurface: UIViewRepresentable {
    @ObservedObject var channelPlayer: ChannelPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        channelPlayer.attachVLCView(view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        channelPlayer.attachVLCView(uiView)
    }
}
