# NM7 IPTV cho iPhone & iPad

Ứng dụng IPTV native dành cho **iPhone và iPad**, được xây dựng trên nền chuẩn **NM7 TV Android 1.0.69** để giữ cùng hệ thống chức năng và trải nghiệm, nhưng dùng API native phù hợp với iOS/iPadOS.

## Trạng thái hiện tại

- **Phiên bản:** 1.0.69
- **Bundle version:** 69
- **Nền tham chiếu:** NM7 TV Android 1.0.69
- **Android reference commit:** `f79fc06009f20e0ac3a5859c0abcfd6ce70a6763`
- **iOS branch:** `release/ios-1.0.69-final-drm-v2`
- **Latest app-build commit:** `1f481d5833cbcf3256c716afb00d69ac659fef4e`
- **Nền tảng:** iOS/iPadOS 16+
- **Thiết bị:** iPhone + iPad
- **UI:** SwiftUI
- **Player chính:** AVPlayer
- **Player dự phòng:** MobileVLCKit / VLC
- **Repository:** Public để sử dụng GitHub-hosted macOS runner
- **CI cuối cùng đã xác minh:** **run #15 — SUCCESS toàn bộ**: Simulator build, Unit Tests, Device Release build, Package IPA và Upload artifact.
- **IPA cuối:** `NM7-IPTV-iOS-1.0.69-final-v2-unsigned.ipa`
- **IPA SHA256:** `ab0b39b4a16e1d4022769da57ab60e98a3b08fe34c98cbac3a2ef6a135dc8d61`
- **Artifact:** `NM7-IPTV-iOS-1.0.69-FINAL-DRM-v2` (ID `11340591479`)
- **Artifact digest:** `sha256:fc2d0f6ff3ae107e55063a738e8fa28b17b30540c3de68b3deeca2e30732d8f4`

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

Đã hoàn thiện pipeline build/package cho iOS 1.0.69. **GitHub Actions run #15 đã SUCCESS toàn bộ** với commit app-build `1f481d5833cbcf3256c716afb00d69ac659fef4e`. IPA unsigned đã được tải xuống và kiểm tra trực tiếp: ZIP integrity PASS, executable PASS, version `1.0.69`, build `69`, `Assets.car` PASS và `nm7_default_background_new.webp` PASS.

Đường DASH/ClearKey CENC đã được sửa và có bộ unit test CENC/DRM riêng; các unit test đã PASS trong run #15. Đây là bằng chứng parser/giải mã mẫu và pipeline build hoạt động đúng trong môi trường CI. Việc xác nhận **phát end-to-end trên iPhone/iPad thật** vẫn cần cài IPA và chạy một stream DASH/ClearKey có quyền phát trên thiết bị thật.

Xem chi tiết tại [`PROGRESS.md`](./PROGRESS.md).