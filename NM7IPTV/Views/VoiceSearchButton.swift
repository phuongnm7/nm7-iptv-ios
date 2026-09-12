import SwiftUI

struct VoiceSearchButton: View {
    @StateObject private var controller = VoiceChannelController()
    let onTranscript: (String) -> Void

    var body: some View {
        Button {
            controller.toggle(onTranscript: onTranscript)
        } label: {
            Image(systemName: controller.isListening ? "waveform.circle.fill" : "mic.circle")
                .foregroundStyle(controller.isListening ? .red : .cyan)
        }
        .accessibilityLabel(controller.isListening ? "Dừng nghe" : "Mở kênh bằng giọng nói")
        .alert("Điều khiển giọng nói", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "")
        }
    }
}
