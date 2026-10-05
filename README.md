# NM7 IPTV cho iPhone & iPad

Ứng dụng IPTV native dành cho **iPhone và iPad**, được xây dựng trên nền chuẩn **NM7 TV Android 1.0.69** để giữ cùng hệ thống chức năng và trải nghiệm, nhưng dùng API native phù hợp với iOS/iPadOS.

## Trạng thái hiện tại

- **Phiên bản:** 1.0.69
- **Bundle version:** 69
- **Nền tham chiếu:** NM7 TV Android 1.0.69
- **Android reference commit:** `f79fc06009f20e0ac3a5859c0abcfd6ce70a6763`
- **iOS branch:** `feat/ios-1.0.69-android-baseline`
- **Latest verified commit:** `d00b0f8bd818cbc79eb1d17f7a351eee272d002b`
- **Nền tảng:** iOS/iPadOS 16+
- **Thiết bị:** iPhone + iPad
- **UI:** SwiftUI
- **Player chính:** AVPlayer
- **Player dự phòng:** MobileVLCKit / VLC
- **Repository:** Public để sử dụng GitHub-hosted macOS runner
- **CI cuối cùng đã xác minh:** **run #147 — SUCCESS toàn bộ**: Simulator build, unit tests, Device Release build, Package IPA và Upload artifact.
- **IPA cuối:** unsigned, SHA256 `1fdb08eb4e803cc79148a3269bbd8b2ae65f5062f6b40d0ff75d3832374a4fb8`
- **Artifact:** `NM7-IPTV-iOS-1.0.69-final-unsigned-IPA` (ID `11334156283`)

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

Đối với nguồn DASH/DRM chưa có đường phát native iOS tương thích, app không cố phá hoặc loại bỏ DRM; trạng thái được báo rõ ràng.

## Build & cài đặt

GitHub Actions đã xác minh thành công bản iOS 1.0.69 ở **run #147**. IPA cuối là bản **unsigned** và đã được kiểm tra integrity, version và executable sau khi đóng gói.

Để cài trên iPhone/iPad thực tế cần ký bằng tài khoản/phương thức Apple phù hợp, ví dụ Apple Development/Ad Hoc hoặc Sideloadly.

## Nguyên tắc phát triển

- Android TV 1.0.69 là **source of truth về chức năng và hành vi**.
- iOS/iPadOS dùng API native phù hợp với Apple.
- Không làm thay đổi dự án Android.
- Không tiếp tục vòng lặp sửa DRM Safari của bản web trong nhánh iOS này.
- Mọi thay đổi lớn phải được build và kiểm tra bằng GitHub Actions trước khi coi là hoàn thành.

## Tiến độ

Đã hoàn thiện nền tảng UI/player, metadata version, header propagation và pipeline đóng gói. Đã bổ sung đường xử lý DASH/ClearKey CENC ở source. Workflow hiện đã chạy thành công trên macOS runner; **run #147 đã build, test và đóng gói IPA 1.0.69 thành công**.

Xem chi tiết tại [`PROGRESS.md`](./PROGRESS.md).