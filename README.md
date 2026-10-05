# NM7 IPTV cho iPhone & iPad

Ứng dụng IPTV native dành cho **iPhone và iPad**, được xây dựng trên nền chuẩn **NM7 TV Android 1.0.69** để giữ cùng hệ thống chức năng và trải nghiệm, nhưng dùng API native phù hợp với iOS/iPadOS.

## Trạng thái hiện tại

- **Phiên bản:** 1.0.69
- **Bundle version:** 69
- **Nền tham chiếu:** NM7 TV Android 1.0.69
- **Android reference commit:** `f79fc06009f20e0ac3a5859c0abcfd6ce70a6763`
- **iOS branch:** `feat/ios-1.0.69-android-baseline`
- **Nền tảng:** iOS/iPadOS 16+
- **Thiết bị:** iPhone + iPad
- **UI:** SwiftUI
- **Player chính:** AVPlayer
- **Player dự phòng:** MobileVLCKit / VLC
- **CI cuối cùng đã xác minh:** run #41 (`a4ee550c...`) build Simulator, unit tests, device build và unsigned IPA thành công trước khi bổ sung CENC.

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

GitHub Actions đã từng tạo artifact IPA unsigned ở các mốc trước. **Bản source hiện tại chưa được phát hành IPA mới** vì runner của GitHub Actions đang bị từ chối trước step build.

Artifact này là IPA **chưa ký**. Để cài trên iPhone/iPad thực tế cần ký bằng tài khoản/phương thức Apple phù hợp, ví dụ Apple Development/Ad Hoc hoặc Sideloadly.

## Nguyên tắc phát triển

- Android TV 1.0.69 là **source of truth về chức năng và hành vi**.
- iOS/iPadOS dùng API native phù hợp với Apple.
- Không làm thay đổi dự án Android.
- Không tiếp tục vòng lặp sửa DRM Safari của bản web trong nhánh iOS này.
- Mọi thay đổi lớn phải được build và kiểm tra bằng GitHub Actions trước khi coi là hoàn thành.

## Tiến độ

Đã hoàn thiện nền tảng UI/player, metadata version, header propagation và pipeline đóng gói. Đã bổ sung đường xử lý DASH/ClearKey CENC ở source. Việc phát hành IPA cuối đang chờ GitHub Actions chạy được trên repository private để thực hiện build/validate thực tế.

Xem chi tiết tại [`PROGRESS.md`](./PROGRESS.md).