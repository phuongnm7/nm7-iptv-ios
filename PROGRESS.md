# NM7 IPTV iOS — tiến độ dự án

## Bàn giao hiện tại — 0.3.0 build 5 (2026-09-12)

- Kho chuẩn: `phuongnm7/nm7-iptv-ios` (private), nhánh `main`.
- Commit player lai: `79ee06dfdd13c7b1cc8fd33a1500ab9c5a996274`.
- GitHub Actions run `34684587175`, job `103529244148`: **SUCCESS**.
- Build Simulator, build thiết bị thật, đóng gói IPA và kiểm tra thư viện VLC đều thành công.
- Artifact: `NM7-IPTV-iOS-0.3.0-unsigned-IPA`, ID `10295356834`.
- Kích thước artifact ZIP: `14,509,712` byte.
- Digest artifact: `sha256:8d1d5e694030edb6dff96e649d0421541becd98375bd78fba58b016809bbb046`.
- IPA chưa ký; ký bằng Sideloadly/Apple ID trước khi cài.
- Việc còn lại: cài 0.3.0 trên iPadOS 16.6.1 và kiểm thử thực tế nhóm VTV. Luồng có DRM vẫn cần hệ thống khóa hợp lệ.

## Mốc player lai 0.3.0 build 5

- Thiết bị thật iPadOS 16.6.1 đã cài và chạy 0.2.2.
- Một số kênh VTVcab phát được bằng AVPlayer nhưng nhóm VTV báo `Cannot Open`.
- Giữ AVPlayer làm bộ phát chính cho HLS tương thích iOS.
- Bổ sung MobileVLCKit 3.3.17 làm bộ phát dự phòng tự động khi AVPlayer báo lỗi hoặc chờ quá 8 giây.
- Chuyển User-Agent, Referer và Cookie của playlist sang VLC; thiết lập network cache riêng cho VLC.
- Giao diện player tự đổi bề mặt hiển thị, không yêu cầu người dùng chọn bộ phát.
- Nâng phiên bản lên 0.3.0 build 5 và chuyển workflow sang CocoaPods workspace.
- Không tác động dự án Android Mobile hoặc Android TV.

## Mốc sửa phát kênh 0.2.2 build 4

- Thiết bị thật cài 0.2.1 thành công nhưng AVPlayer báo `Cannot Open` khi mở kênh.
- Danh sách nhóm, tên và logo đều tải được; lỗi được khoanh vùng ở URL phát/header.
- Đồng bộ cách xử lý từ parser Android chuẩn: tách header gắn sau URL bằng dấu `|`, giải mã phần trăm và không đưa chuỗi header vào URL AVPlayer.
- Hỗ trợ `#EXTVLCOPT`, `#EXTHTTP`, cùng User-Agent, Referer, Origin, Cookie và header hợp lệ khác.
- AVPlayer nhận toàn bộ header của kênh; hộp lỗi bổ sung failure reason khi iOS cung cấp.
- Thêm unit test cho URL inline-header và JSON header.
- Version 0.2.2 build 4.

## Mốc sửa đóng gói 0.2.1 build 3

- Sideloadly 0.60 báo `Guru Meditation ... Can't listdir a file` với IPA 0.2.0.
- Đổi sang ZIP IPA chuẩn, loại bỏ extended attributes và resource-fork metadata.
- Workflow bắt buộc kiểm tra `Payload/NM7IPTV.app/Info.plist` và executable.

## Mốc 0.2.0 — điều khiển player và giọng nói

- Thêm chuyển kênh trước/sau trong cùng nhóm bằng nút hoặc vuốt ngang.
- Thêm trạng thái đang tải, hộp thoại lỗi và nút thử lại.
- Thêm tìm/mở kênh bằng giọng nói tiếng Việt ở màn hình chính và player.
- Chuẩn hóa câu lệnh, bỏ dấu và đối chiếu tên gần đúng.

## Mốc khởi tạo 0.1.0

- Repo độc lập dành riêng cho iPhone/iPad: `phuongnm7/nm7-iptv-ios`.
- SwiftUI, iOS/iPadOS 16+, parser M3U, cache, nhóm, tìm kiếm, yêu thích/gần đây.
- Quản lý nhiều nguồn; nguồn mặc định ẩn URL và tự phục hồi sau khi xóa nguồn tùy chỉnh.
