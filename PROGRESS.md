# NM7 IPTV iOS — tiến độ dự án

## Mốc hiện tại — iOS 1.0.69 Android baseline (2026-10-05)

### Nền chuẩn đã xác nhận

- Dự án iOS: `phuongnm7/nm7-iptv-ios`.
- Nhánh phát triển: `feat/ios-1.0.69-android-baseline`.
- Nền tham chiếu: **NM7 TV Android 1.0.69**.
- Android 1.0.69 reference release: `v1.0.69-fast-vtvcab-logo-16`.
- Android baseline commit: `f79fc06009f20e0ac3a5859c0abcfd6ce70a6763`.
- Mục tiêu: chuyển chức năng và hành vi cốt lõi của Android 1.0.69 sang app native cho **iPhone + iPad**.
- Không tiếp tục sửa DRM cho bản web Safari trong phạm vi nhánh iOS này.

### Trạng thái build hiện tại

- iOS Marketing Version: **1.0.69**.
- iOS Bundle Version: **69**.
- Deployment target: **iOS/iPadOS 16.0+**.
- Thiết bị: **iPhone + iPad**.
- GitHub Actions run **#26: SUCCESS**.
- Đã pass: Generate Xcode workspace; build Simulator; unit tests; build device app; package + validate unsigned IPA; upload artifact.
- Artifact: `NM7-IPTV-iOS-1.0.69-unsigned-IPA` (ID `11326001848`).
- Kích thước artifact: **14,563,563 bytes**.
- SHA-256: `b394c476eb76e1cbb665a1a58b02af29d0af374f053af204a49b088a2a92d726`.
- Commit của run #26: `b150351531481ba5dddd0eeea4a0dfd830e19c85`.
- IPA hiện **unsigned**; cài thiết bị thật cần ký bằng Apple Development/Ad Hoc hoặc Sideloadly.

### Những phần đã được chuyển sang nền iOS 1.0.69

- Khung SwiftUI riêng cho iPhone/iPad.
- Model Channel và PlaylistSource.
- Parser M3U và quản lý nguồn IPTV.
- Cache playlist và tải lại nguồn.
- Nhóm kênh, tìm kiếm, yêu thích và gần đây.
- Điều hướng: Trang chính, Truyền hình, Thể thao, Tất cả, Yêu thích, Gần đây, Nguồn IPTV, Tùy chọn ứng dụng.
- Tải lại playlist và tìm kiếm bằng giọng nói.
- Mở YouTube.
- Player native iOS: AVPlayer là player chính cho HLS/MP4 tương thích iOS; MobileVLCKit/VLC là fallback khi AVPlayer không mở được hoặc stall kéo dài.
- Truyền User-Agent, Referer, Cookie và HTTP headers cần thiết từ playlist.
- Xử lý buffering, stalled và fallback sang VLC.
- Metadata bundle đã đồng bộ lên 1.0.69.

### Nguyên tắc player cho iOS

- Ưu tiên API native của Apple thay vì sao chép pipeline Android.
- Không phá hoặc tháo DRM của nguồn bên thứ ba.
- Với DASH/DRM chưa có đường phát native iOS tương thích, app báo trạng thái rõ ràng.
- Với HLS tương thích iOS, ưu tiên AVPlayer; lỗi tương thích hoặc stall kéo dài thì dùng VLC fallback.

### Việc đang thực hiện tiếp

1. Đối chiếu từng màn hình với Android TV 1.0.69 để đồng bộ bố cục, khoảng cách, font, card kênh, logo và player UI.
2. Đồng bộ hành vi chuyển kênh, thứ tự nhóm, yêu thích/gần đây và tìm kiếm.
3. Hoàn thiện player screen cho iPhone/iPad: fullscreen, landscape, điều khiển phát/tạm dừng, chuyển kênh và xử lý nền.
4. Kiểm thử nguồn HLS thực tế trên iPhone/iPad, ưu tiên VTV/VTVcab/Thể Thao.
5. Giữ workflow build + unit test + IPA validation xanh trên GitHub Actions.

### Lịch sử nền trước 1.0.69

## Bàn giao 0.3.0 build 5 (2026-09-12)

- Repo `phuongnm7/nm7-iptv-ios`; commit player lai: `79ee06dfdd13c7b1cc8fd33a1500ab9c5a996274`.
- GitHub Actions run `34684587175`: **SUCCESS**.
- Build Simulator, device, IPA và VLC đều thành công.
- IPA chưa ký; ký bằng Sideloadly/Apple ID trước khi cài.

## Mốc player lai 0.3.0

- AVPlayer là player chính; MobileVLCKit 3.3.17 là fallback.
- Hỗ trợ User-Agent, Referer, Cookie và cache mạng riêng cho VLC.
- Giao diện player tự đổi bề mặt hiển thị.

## Mốc 0.2.2 build 4

- Khoanh vùng lỗi Cannot Open ở URL/header.
- Hỗ trợ inline headers, `#EXTVLCOPT`, `#EXTHTTP`, User-Agent, Referer, Origin, Cookie.
- Có unit test cho URL inline-header và JSON header.

## Mốc 0.2.1 build 3

- Sửa đóng gói IPA để tương thích Sideloadly 0.60.

## Mốc 0.2.0

- Chuyển kênh, trạng thái tải, lỗi, thử lại và tìm kênh bằng giọng nói tiếng Việt.

## Mốc khởi tạo 0.1.0

- SwiftUI, iOS/iPadOS 16+, parser M3U, cache, nhóm, tìm kiếm, yêu thích/gần đây và quản lý nhiều nguồn.