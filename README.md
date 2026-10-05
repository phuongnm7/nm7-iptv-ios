# NM7 IPTV cho iPhone & iPad

Ứng dụng IPTV native dành cho **iPhone và iPad**, được xây dựng trên nền chuẩn **NM7 TV Android 1.0.69** để giữ cùng hệ thống chức năng và trải nghiệm, nhưng dùng API native phù hợp với iOS/iPadOS.

## Trạng thái hiện tại

- **Phiên bản:** 1.0.69
- **Bundle version:** 69
- **Nền tham chiếu:** NM7 TV Android 1.0.69
- **Android reference commit:** `f79fc06009f20e0ac3a5859c0abcfd6ce70a6763`
- **iOS branch:** `release/ios-1.0.69-final-drm-v2`
- **Latest source commit:** `1f481d5833cbcf3256c716afb00d69ac659fef4e`
- **Nền tảng:** iOS/iPadOS 16+
- **Thiết bị:** iPhone + iPad
- **UI:** SwiftUI
- **Player chính:** AVPlayer
- **Player dự phòng:** MobileVLCKit / VLC
- **Repository:** Public để sử dụng GitHub-hosted macOS runner

> **CẢNH BÁO TRẠNG THÁI:** GitHub Actions hiện có run #15 **SUCCESS** ở mức build/package và unit test. Tuy nhiên, điều đó **không đồng nghĩa bản app đã chạy đúng trên iPhone/iPad thật**. Theo kết quả kiểm tra thực tế hiện tại, các lỗi runtime trước đây vẫn còn và bản iOS 1.0.69 **chưa được coi là hoàn thành**.

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

Đối với **DASH/ClearKey CENC**, app có đường xử lý native: MPD → fragmented MP4/HLS → giải mã sample CENC bằng ClearKey → AVPlayer. Parser CENC đã được sửa nhiều vòng để đọc `tenc`, `senc`, `trun`, `saiz/saio` và nhiều `moof`. Tuy nhiên, **end-to-end runtime trên thiết bị thật vẫn chưa đạt**, nên chưa được xác nhận là đã phát DRM ổn định.

Với Widevine/PlayReady, app không giả định rằng build thành công đồng nghĩa đã có CDM tương ứng.

## Các vấn đề còn tồn tại — cần xử lý tiếp

Theo kết quả kiểm tra hiện tại, bản iOS vẫn còn các lỗi runtime đã được phản ánh trước đó:

- **DASH/ClearKey DRM chưa phát ổn định trên iPhone/iPad thật.**
- Đường **MPD → HLS/fMP4 → CENC decrypt → AVPlayer** chưa có bằng chứng runtime end-to-end trên thiết bị thật.
- Một số stream DRM/định dạng trước đây không phát được vẫn chưa được xác nhận đã khắc phục hoàn toàn.
- Cần tiếp tục đối chiếu **giao diện với Android TV 1.0.69**, bao gồm vị trí điều khiển, trạng thái player và hình nền mặc định.
- Không được đánh dấu “hoàn thành” chỉ dựa trên việc CI xanh.

## Những gì đã được sửa trong source nhưng chưa coi là đã giải quyết hoàn toàn

- Sửa vị trí đọc `default_KID` / `default_Per_Sample_IV_Size` của `tenc`.
- Bổ sung đọc constant IV.
- Bổ sung kiểm tra số sample giữa `senc` và `trun`.
- Bổ sung xử lý `saiz/saio` khi không có `senc`.
- Bổ sung xử lý nhiều `moof` trong một SegmentBase resource.
- Thêm nhánh CENC/CBCS trong processor.
- Không để `MPDToMP4Resolver` bỏ qua media resource processor CENC.
- Bỏ spinner cố định phủ trên video.
- Đưa microphone/fullscreen/favorite vào video pane để tránh chồng vùng nhóm.
- Thêm unit test cho ClearKey inline `KID:KEY` và named-pair.

Các thay đổi trên là **các bước kỹ thuật đã triển khai**, không phải bằng chứng rằng mọi lỗi runtime đã hết.

## CI / build

- **Run #15:** SUCCESS toàn bộ pipeline CI, gồm Simulator build, Unit Tests, Device Release build, Package IPA và Upload artifact.
- **Commit của run #15:** `1f481d5833cbcf3256c716afb00d69ac659fef4e`.
- Run #14 trước đó FAIL tại CENC unit test do parser `trun` đọc sai vị trí FullBox; lỗi đó đã được sửa ở commit sau.
- Run #15 chỉ chứng minh rằng source hiện tại **build được, test tự động hiện tại pass và đóng gói được**.

## Build & cài đặt

IPA iOS được đóng gói ở dạng **unsigned**. Để cài trên iPhone/iPad thực tế cần ký bằng tài khoản/phương thức Apple phù hợp, ví dụ Apple Development/Ad Hoc hoặc Sideloadly.

## Nguyên tắc phát triển

- Android TV 1.0.69 là **source of truth về chức năng và hành vi**.
- iOS/iPadOS dùng API native phù hợp với Apple.
- Không làm thay đổi dự án Android.
- Không tiếp tục vòng lặp sửa DRM Safari của bản web trong nhánh iOS này.
- Không coi build CI xanh là bằng chứng phát được DRM trên thiết bị thật.
- Mọi thay đổi DRM quan trọng phải có test parser/decrypt và sau đó phải được kiểm tra runtime bằng stream DASH/ClearKey hợp lệ.

## Tiến độ

**Chưa hoàn thành.** Source hiện tại đã có một lượng lớn xử lý CENC/ClearKey và CI run #15 đã xanh, nhưng lỗi runtime mà người dùng đang gặp vẫn chưa được giải quyết dứt điểm. Mốc tiếp theo phải tập trung vào **nguyên nhân khiến stream DASH/ClearKey thực tế vẫn không phát**, thay vì tiếp tục chỉ làm cho build xanh.

Xem chi tiết tại [`PROGRESS.md`](./PROGRESS.md).
