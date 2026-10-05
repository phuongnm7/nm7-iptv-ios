import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section("NM7 TV") {
                LabeledContent("Phiên bản", value: "1.0.69")
                LabeledContent("Nền chuẩn", value: "Android TV 1.0.69")
                LabeledContent("Thiết bị", value: "iPhone / iPad")
                LabeledContent("Player", value: "AVPlayer + VLC")
            }
            Section("Thông tin") {
                Text("NM7 TV là ứng dụng xem playlist IPTV cá nhân. Ứng dụng không cung cấp nội dung truyền hình.")
            }
        }
        .navigationTitle("Thông tin")
    }
}
