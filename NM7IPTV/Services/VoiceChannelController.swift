import AVFoundation
import Speech

@MainActor
final class VoiceChannelController: ObservableObject {
    @Published private(set) var isListening = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi_VN"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle(onTranscript: @escaping (String) -> Void) {
        if isListening {
            stop()
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else {
                    self.errorMessage = "Bạn cần cho phép nhận dạng giọng nói trong Cài đặt."
                    return
                }
                self.start(onTranscript: onTranscript)
            }
        }
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func start(onTranscript: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Nhận dạng giọng nói hiện không khả dụng."
            return
        }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, when in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result, result.isFinal {
                        let text = result.bestTranscription.formattedString
                        self.stop()
                        onTranscript(text)
                    } else if let error {
                        self.stop()
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            stop()
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        if audioEngine.isRunning { audioEngine.stop() }
    }
}
