import SwiftUI

struct AboutView: View {
    private var version: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(name) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ứng dụng") {
                    LabeledContent("Tên", value: "NM7 IPTV")
                    LabeledContent("Phiên bản", value: version)
                    LabeledContent("Nền tảng", value: "iPhone / iPad")
                }
                Section("Thông tin") {
                    Text("Ứng dụng được phát triển bởi Phuongnm7 vì mục đích cá nhân, không vì mục đích thương mại.")
                }
                Section("Nội dung") {
                    Text("Ứng dụng không cung cấp nội dung truyền hình. Người dùng chịu trách nhiệm đối với playlist và quyền truy cập nội dung.")
                }
            }
            .navigationTitle("Thông tin ứng dụng")
        }
    }
}
