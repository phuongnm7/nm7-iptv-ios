# NM7 IPTV iOS — tiến độ dự án

## Mốc hiện tại — iOS 1.0.69 Android baseline (2026-10-05)

### Trạng thái thực tế

- Dự án iOS: phuongnm7/nm7-iptv-ios.
- Nhánh làm việc: release/ios-1.0.69-final-drm-v2.
- Nền tham chiếu: NM7 TV Android 1.0.69.
- Android baseline commit: f79fc06009f20e0ac3a5859c0abcfd6ce70a6763.
- Mục tiêu: chuyển chức năng và hành vi cốt lõi của Android 1.0.69 sang app native cho iPhone + iPad.
- Không tiếp tục sửa DRM Safari/web trong nhánh iOS này.
- iOS Marketing Version: 1.0.69.
- iOS Bundle Version: 69.
- Deployment target: iOS/iPadOS 16.0+.
- Repository public để GitHub-hosted macOS runner chạy build.

### Điều quan trọng cần ghi rõ

**BẢN 1.0.69 HIỆN CHƯA HOÀN THÀNH.**

Người dùng đã kiểm tra thực tế và phản hồi rằng các lỗi trước đây vẫn còn nguyên. Vì vậy không được lấy trạng thái CI xanh để kết luận app đã hoạt động đúng.

Các vấn đề runtime đang còn:

1. DASH/ClearKey DRM chưa phát ổn định trên iPhone/iPad thật.
2. Chưa có bằng chứng end-to-end đáng tin cậy cho luồng MPD → HLS/fMP4 → CENC/CBCS decrypt → AVPlayer → video thực tế trên thiết bị thật.
3. Một số stream DRM/định dạng từng báo lỗi chưa được xác nhận đã xử lý dứt điểm.
4. Vẫn phải tiếp tục đối chiếu giao diện với Android TV 1.0.69, đặc biệt vùng player, điều khiển và hình nền.
5. Không được coi build thành công hoặc unit test pass là DRM đã hoạt động.

### CI hiện tại

- Commit source mới nhất trước cập nhật tài liệu: 1f481d5833cbcf3256c716afb00d69ac659fef4e.
- GitHub Actions run #15 (37296937858) — SUCCESS toàn bộ: Simulator build, Unit Tests, Device Release build, Package IPA và Upload artifact.
- Run #14 (37296028753) FAIL tại CENC unit test với lỗi "trun thiếu sample size".
- Nguyên nhân run #14 đã được xác định: các parser FullBox trong CENC bỏ qua sai phần FullBox header khi tính cursor.
- Commit sửa parser: 84c769b0cdd14f46d190213dc3bf39d43475dc6f.
- Run #15 sau đó đã xanh sau khi sửa test data offset, nhưng run xanh này chỉ chứng minh CI/build/test suite hiện tại pass, chưa chứng minh stream thực tế trên iPhone/iPad đã phát.
- Cập nhật README sau mốc này được commit tại: 5bb7cc90054b378cc5f9059abec5930c8027e707.

### Những thay đổi kỹ thuật đã triển khai

#### CENC / ClearKey

- Sửa đọc tenc để lấy đúng isProtected, default_Per_Sample_IV_Size và default_KID.
- Sửa vị trí đọc constant IV khi IV size bằng 0.
- Chuẩn hóa KID sang Base64URL khi cache ClearKey và không tự ý thay KID khi license trả nhiều key.
- Hỗ trợ ClearKey inline KID:KEY.
- Hỗ trợ ClearKey dạng named pair kid=...&key=....
- Hỗ trợ JWK ClearKey.
- Hỗ trợ senc override-track-encryption-parameters.
- Hỗ trợ saiz/saio khi senc không có.
- Hỗ trợ xử lý nhiều moof trong cùng SegmentBase resource.
- Có nhánh xử lý CENC/CBCS trong custom media resource processor.
- MPDToMP4Resolver không được phép bỏ qua CENC media resource processor.
- Resource loader đã có route riêng cho cenc-init / cenc-segment.
- Processor error được đẩy lên player thay vì để UI loading vô hạn.

#### Player/UI

- Đã bỏ ProgressView spinner cố định phủ video.
- Đã đưa microphone / fullscreen / favorite vào vùng video pane để tránh chồng lên selector nhóm.
- Hình nền mặc định được đóng gói từ nm7_default_background_new.webp theo Android source-of-truth.

### Unit test hiện có

- CENC fragment decrypt với inline ClearKey.
- Nhiều moof trong một SegmentBase resource.
- tenc version 0.
- tenc version 1.
- constant IV.
- malformed tenc.
- ClearKey legacy / named-pair / JWK metadata.
- M3U/DRM metadata và channel logo regression.

### Giới hạn của kết quả test hiện tại

Test CENC hiện đang dùng synthetic test vector tự tạo trong XCTest. Điều này xác nhận thuật toán xử lý dữ liệu CENC theo vector đã dựng, nhưng không thay thế kiểm thử với một MPD/fragment/license thật mà iPhone/iPad đang gặp.

Do phản hồi thực tế cho biết lỗi cũ vẫn còn, bước tiếp theo phải tập trung vào:

- lấy đúng MPD thực tế đang lỗi;
- tải init segment + media segment thực tế;
- đối chiếu tenc, moof/traf/tfhd/trun/senc/saiz/saio, sample offset và scheme;
- xác định AVPlayer đang nhận đúng byte range và sample đã giải mã hay chưa;
- kiểm tra chính xác KID/KEY/license flow của stream;
- chỉ sau khi có bằng chứng runtime mới đánh dấu DRM hoàn thành.

### Trạng thái đóng gói

IPA iOS là unsigned, cần ký bằng Apple Development/Ad Hoc hoặc Sideloadly trước khi cài thiết bị thật.

### Quy tắc trạng thái từ thời điểm này

- CI xanh = build/test/package xanh.
- DRM chạy thật trên iPhone/iPad = chỉ đánh dấu đạt sau khi kiểm tra runtime thành công.
- Không xóa hoặc che giấu các lỗi runtime đã được người dùng phản ánh.
- Android TV 1.0.69 vẫn là source of truth về chức năng và hành vi.
- Không tiếp tục sửa DRM Safari/web.
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