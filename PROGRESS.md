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

- **Commit app-build đã kiểm tra:** `1f481d5833cbcf3256c716afb00d69ac659fef4e`.
- **GitHub Actions run #153 — SUCCESS toàn bộ**: Simulator, Unit Tests, Device Release, Package IPA và Upload Artifact.
- **Artifact mới:** `NM7-IPTV-iOS-1.0.69-final-unsigned-IPA`, ID `11335080731`.
- **Artifact digest:** `sha256:3ea7d2d447aaed7413f10de7afb6a6631f1ae167e7f35082c5b6e2a55c2ef4e6`.
- IPA đã tải và kiểm tra: version `1.0.69`, build `69`, ZIP integrity PASS.
- SHA256 file IPA mới: `d3d8ac8be9930d3216108ae737503a5bac20d5499cd43daeb82bced2f73b0cc0`.

- iOS Marketing Version: **1.0.69**.
- iOS Bundle Version: **69**.
- Deployment target: **iOS/iPadOS 16.0+**.
- Thiết bị mục tiêu: **iPhone + iPad**.
- Repository đã chuyển sang **Public** để GitHub-hosted macOS runner có thể chạy build.
- **Run #15 kiểm tra sau tải IPA:** `CFBundleShortVersionString = 1.0.69`, `CFBundleVersion = 69`, executable `Payload/NM7IPTV.app/NM7IPTV`, `Assets.car` và `nm7_default_background_new.webp` đều PASS.
- ZIP integrity của IPA: **PASS**.
- IPA là **unsigned**, cần ký bằng Apple ID/Sideloadly hoặc phương thức phân phối Apple phù hợp trước khi cài thiết bị thật.

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

### Sửa lỗi DRM/CENC và player UI — 2026-10-05

- Sửa parser `tenc` của CENC: đọc đúng `default_Per_Sample_IV_Size` và `default_KID` theo cấu trúc Track Encryption Box thay vì lệch 1 byte.
- Hỗ trợ đọc constant IV theo đúng vị trí sau KID khi per-sample IV size bằng 0.
- Bắt lỗi mismatch giữa số sample trong `senc` và `trun` thay vì âm thầm giải mã thiếu sample.
- Giữ đường ClearKey CENC theo playlist metadata `drm_legacy` / `license_key`, không bypass DRM.
- Xóa spinner `ProgressView` phủ lên video player để không còn vòng quay cố định khi live stream đang phát/buffer.
- Đưa 3 nút **microphone / toàn màn hình / yêu thích** vào vùng điều khiển phía trên của **video pane**, không còn phủ lên vùng chọn nhóm kênh.
- Thêm unit test cho inline ClearKey dạng `KID:KEY`.
- Run #15 xác nhận toàn bộ source, unit tests, device build và đóng gói IPA thành công.

### Nguyên tắc player cho iOS

- Ưu tiên API native của Apple thay vì sao chép pipeline Android.
- Không phá hoặc tháo DRM của nguồn bên thứ ba.
- Với DASH/ClearKey CENC, app có đường xử lý native: MPD → fragmented MP4/HLS → giải mã sample CENC bằng ClearKey → AVPlayer.
- Với Widevine/PlayReady không có CDM tương ứng trong nhánh này, app không cố phá DRM và không giả định rằng build thành công đồng nghĩa đã phát được.
- Với HLS tương thích iOS, ưu tiên AVPlayer; lỗi tương thích hoặc stall kéo dài thì dùng VLC fallback.
- Với HLS tương thích iOS, ưu tiên AVPlayer; lỗi tương thích hoặc stall kéo dài thì dùng VLC fallback.

### Việc còn cần xác nhận ngoài CI

1. Cài IPA lên iPhone/iPad thật và chạy một stream DASH/ClearKey CENC có quyền phát để xác nhận end-to-end MPD → segment → KID/KEY → decryption → AVPlayer.
2. Tiếp tục đối chiếu UI iOS với Android TV 1.0.69 trên thiết bị thật và hoàn thiện các khác biệt nhỏ về bố cục/điều khiển nếu phát hiện trong test thực tế.

**Trạng thái CI:** run #15 đã xanh toàn bộ.

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