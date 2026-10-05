import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppViewModel

    @AppStorage("nm7.showSource") private var showSource = false
    @AppStorage("nm7.backgroundAudio") private var backgroundAudio = true
    @AppStorage("nm7.autoLandscape") private var autoLandscape = true
    @AppStorage("nm7.fastStartup") private var fastStartup = true

    @State private var cacheMessage = ""

    var body: some View {
        Form {
            Section("Phát lại") {
                Toggle("Hiện nguồn phát trong player", isOn: $showSource)
                Toggle("Cho phép âm thanh nền", isOn: $backgroundAudio)
                Toggle("Tự xoay ngang khi phát", isOn: $autoLandscape)
                Toggle("Ưu tiên khởi động nhanh", isOn: $fastStartup)
            }

            Section("Playlist") {
                Button {
                    Task { await model.reload() }
                } label: {
                    Label("Tải lại playlist hiện tại", systemImage: "arrow.clockwise")
                }

                Button("Xóa cache playlist") {
                    clearPlaylistCache()
                }

                if !cacheMessage.isEmpty {
                    Text(cacheMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ứng dụng") {
                Button {
                    model.openYouTube()
                } label: {
                    Label("Mở YouTube", systemImage: "play.rectangle.fill")
                }

                LabeledContent("Phiên bản", value: "1.0.69")
                LabeledContent("Nền chuẩn", value: "Android TV 1.0.69")
                LabeledContent("Thiết bị", value: "iPhone / iPad")
            }

            Section("Player") {
                LabeledContent("HLS / MP4", value: "AVPlayer")
                LabeledContent("Fallback", value: "MobileVLCKit")
                Text("Nguồn DASH/DRM chỉ phát được khi nguồn cung cấp cơ chế tương thích Apple như HLS/FairPlay. Ứng dụng không bỏ hoặc phá DRM.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tùy chọn ứng dụng")
    }

    private func clearPlaylistCache() {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("nm7-1.0.69-channels.json")

        guard let cache else { return }
        do {
            try FileManager.default.removeItem(at: cache)
            cacheMessage = "Đã xóa cache playlist."
        } catch {
            cacheMessage = FileManager.default.fileExists(atPath: cache.path)
                ? "Không thể xóa cache: \(error.localizedDescription)"
                : "Cache playlist không tồn tại."
        }
    }
}
