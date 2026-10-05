# NM7 IPTV cho iPhone & iPad

Ứng dụng IPTV native dành cho **iPhone và iPad**, được xây dựng trên nền chuẩn **NM7 TV Android 1.0.69** để giữ cùng hệ thống chức năng và trải nghiệm, nhưng dùng API native phù hợp với iOS/iPadOS.

## Trạng thái hiện tại

- **Phiên bản:** 1.0.69
- **Bundle version:** 69
- **Nền tham chiếu:** NM7 TV Android 1.0.69
- **Android reference commit:** `f79fc06009f20e0ac3a5859c0abcfd6ce70a6763`
- **iOS branch:** `feat/ios-1.0.69-android-baseline`
- **Latest verified commit:** `88743022709311c19537b57ce3516a4a6ff077bd`
- **Nền tảng:** iOS/iPadOS 16+
- **Thiết bị:** iPhone + iPad
- **UI:** SwiftUI
- **Player chính:** AVPlayer
- **Player dự phòng:** MobileVLCKit / VLC
- **Repository:** Public để sử dụng GitHub-hosted macOS runner
- **CI cuối cùng đã xác minh:** **run #153 — SUCCESS toàn bộ**: Simulator build, Unit Tests, Device Release build, Package IPA và Upload artifact.
- **IPA mới:** unsigned, SHA256 `d3d8ac8be9930d3216108ae737503a5bac20d5499cd43daeb82bced2f73b0cc0`
- **Artifact mới:** `NM7-IPTV-iOS-1.0.69-final-unsigned-IPA` (ID `11335080731`)
- **Artifact digest:** `sha256:3ea7d2d447aaed7413f10de7afb6a6631f1ae167e7f35082c5b6e2a55c2ef4e6`

## Mục tiêu của bản iOS 1.0.69

Bản này lấy **Android TV 1.0.69 làm source of truth về chức năng và hành vi**, sau đó chuyển từng phần sang iOS native:

- Màn hình chính và hệ thống nhóm kênh.
- Truyền hình, Thể thao, Tất cả kênh.
- Yêu thích và Gần đây.
- Tìm kiếm và tìm bằng giọng nói.
- Quản lý nhiều nguồn IPTV và tải lại playlist.
- Logo và card kênh.
- Player/fullscreen và chuyển kênh.
- Cache và khôi phục playlist.

## Player iOS

**AVPlayer → player native chính** cho HLS/MP4 tương thích iOS.

**MobileVLCKit/VLC → fallback** khi AVPlayer không mở được hoặc bị stall kéo dài.

App truyền các header hợp lệ của playlist như User-Agent, Referer và Cookie khi cần.

Đối với **DASH/ClearKey CENC**, app có đường xử lý native: MPD → fragmented MP4/HLS → giải mã sample CENC bằng ClearKey → AVPlayer. Parser CENC đã được sửa để đọc đúng `tenc` KID/IV. Với Widevine/PlayReady, app không giả định rằng build thành công đồng nghĩa đã có CDM tương ứng.

## Các sửa lỗi player/DRM mới nhất

- Sửa `tenc` CENC bị lệch byte khi đọc KID và IV size.
- Kiểm tra `senc`/`trun` sample count.
- Bỏ spinner cố định phủ lên video.
- Đưa 3 nút microphone / fullscreen / favorite vào vùng video pane, tránh che nhóm kênh.
- Thêm unit test cho ClearKey inline `KID:KEY`.

## Build & cài đặt

GitHub Actions đã xác minh thành công bản iOS 1.0.69 ở **run #153**. IPA cuối là bản **unsigned** và đã được kiểm tra integrity, version và executable sau khi đóng gói.

Để cài trên iPhone/iPad thực tế cần ký bằng tài khoản/phương thức Apple phù hợp, ví dụ Apple Development/Ad Hoc hoặc Sideloadly.

## Nguyên tắc phát triển

- Android TV 1.0.69 là **source of truth về chức năng và hành vi**.
- iOS/iPadOS dùng API native phù hợp với Apple.
- Không làm thay đổi dự án Android.
- Không tiếp tục vòng lặp sửa DRM Safari của bản web trong nhánh iOS này.
- Mọi thay đổi lớn phải được build và kiểm tra bằng GitHub Actions trước khi coi là hoàn thành.

## Tiến độ

Đã hoàn thiện nền tảng UI/player, metadata version, header propagation và pipeline đóng gói. Đã bổ sung và sửa đường xử lý DASH/ClearKey CENC ở source, bao gồm parser `tenc` KID/IV và sample-count validation. Workflow **run #153** đã build, test và đóng gói IPA 1.0.69 thành công. Việc xác nhận cuối cùng của DRM end-to-end vẫn cần chạy kênh DASH/ClearKey thực tế trên iPhone/iPad có quyền phát.

Xem chi tiết tại [`PROGRESS.md`](./PROGRESS.md).