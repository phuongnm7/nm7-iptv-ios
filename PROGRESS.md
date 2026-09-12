# NM7 IPTV iOS — tiến độ dự án

## Mốc sửa đóng gói 0.2.1 build 3

- Sideloadly 0.60 báo `Guru Meditation ... Can't listdir a file` với IPA 0.2.0.
- Nguyên nhân được khoanh vùng ở cấu trúc archive do cách đóng gói bằng `ditto --sequesterRsrc`, không phải kết nối iPad hoặc Apple ID.
- Đổi sang ZIP IPA chuẩn, loại bỏ extended attributes và không đưa resource-fork metadata vào archive.
- Workflow bắt buộc kiểm tra ZIP và xác nhận tồn tại `Payload/NM7IPTV.app/Info.plist` cùng executable trước khi upload.
- Tăng version lên 0.2.1 build 3 và đồng bộ User-Agent. Chờ workflow xác nhận và tạo artifact mới.


## Bàn giao hiện tại — iOS 0.2.0 build 2 (2026-09-12)

- Repo chuẩn: `phuongnm7/nm7-iptv-ios` (private), nhánh `main`; dự án độc lập với Android Mobile và Android TV.
- Bản Android tham chiếu được khóa tại `phuongnm7/iptv-player-android`, nhánh `release/mobile-1.10.19-standard`.
- Mã iOS hiện hành: SwiftUI + AVPlayer, yêu cầu iOS/iPadOS 16 trở lên.
- Commit tính năng 0.2.0: `c03bc70907e77e5befc38576988619ca202e65c7`.
- Commit workflow đóng gói IPA: `4b336dddc42b480d42928c940238766621b7d6c5`.
- Workflow bàn giao: run `34680969017`, job `103519410409`.
- Build Simulator, build thiết bị iPhone/iPad, đóng gói và upload IPA đều **SUCCESS**.
- Artifact: `NM7-IPTV-iOS-0.2.0-unsigned-IPA`, ID `10294078290`, kích thước archive `222883` bytes.
- Artifact digest: `sha256:725a4d34237010ec2cc8598c32849daad035534d5fb8a9cc60f84a86388cecbf`.
- Trong artifact có `NM7-IPTV-iOS-0.2.0-unsigned.ipa` và file SHA-256 tương ứng.
- IPA chưa ký; cần ký bằng Apple ID/Apple Developer qua Sideloadly, AltStore hoặc Xcode trước khi cài trên iPad thật.

### Kiểm thử thiết bị thật cần làm tiếp

1. Ký và cài IPA lên iPhone/iPad, bật Developer Mode và tin cậy hồ sơ nhà phát triển nếu iOS yêu cầu.
2. Xác nhận nguồn mặc định tải được, URL nguồn mặc định không xuất hiện trong phần quản lý nguồn.
3. Thử thêm/chọn/xóa nguồn tùy chỉnh và xác nhận ứng dụng quay lại nguồn mặc định.
4. Thử HLS, logo kênh, nhóm, tìm kiếm, Yêu thích/Gần đây, vuốt đổi kênh và nút trước/sau.
5. Cho phép Microphone/Speech Recognition; thử gọi kênh ở màn hình chính và khi đang xem.
6. Ghi lại video hoặc thông báo lỗi từ thiết bị thật để xử lý mốc tiếp theo.
7. Muốn phát hành IPA ký sẵn/TestFlight cần Apple Development Team, certificate và provisioning profile của chủ dự án.

## Mốc 0.2.0 — điều khiển player và giọng nói

- Thêm chuyển kênh trước/sau trong cùng nhóm bằng nút hoặc vuốt ngang trên video.
- Thêm trạng thái đang tải và hộp thoại lỗi phát, có nút thử lại.
- Thêm tìm và mở kênh bằng giọng nói tiếng Việt ở màn hình chính và trong player.
- Chuẩn hóa câu lệnh như “mở kênh”, “xem kênh”, “phát kênh”, bỏ dấu và đối chiếu tên gần đúng.
- Thêm quyền Microphone/Speech Recognition và unit test bộ ghép tên kênh.
- Tách quản lý AVPlayer để theo dõi buffering/lỗi và giữ bộ đệm 12 giây.
- Version: 0.2.0 (build 2).
- Commit: `c03bc70907e77e5befc38576988619ca202e65c7`.
- Workflow run `34680761012`, job `103518856567`: tạo Xcode project và build iPhone/iPad Simulator **SUCCESS**.


## Mốc khởi tạo 0.1.0 — 2026-09-12

- Kho riêng tư dành riêng cho iPhone/iPad; không dùng chung với Android Mobile hoặc Android TV.
- Bản chức năng tham chiếu: NM7 IPTV Android Mobile 1.10.19, nhánh chuẩn `release/mobile-1.10.19-standard`.
- Công nghệ: SwiftUI, AVPlayer, iOS/iPadOS 16+.
- Đã tạo parser M3U, tải playlist bất đồng bộ, cache danh sách kênh để mở lại nhanh.
- Đã tạo giao diện thích ứng iPhone/iPad: nhóm kênh, tìm kiếm, Tất cả/Yêu thích/Gần đây, thẻ kênh và player dọc/ngang.
- Đã tạo quản lý nhiều nguồn; nguồn mặc định được ẩn URL, có nút chọn lại và tự phục hồi khi xóa nguồn tùy chỉnh đang dùng.
- Đã thêm lưu Yêu thích/Gần đây, header User-Agent/Referer khi phát và bộ đệm AVPlayer.
- Đã thêm unit test parser và GitHub Actions build bằng Xcode Simulator.
- Phiên bản: 0.1.0 (build 1).

## Giới hạn hiện tại

- AVPlayer hỗ trợ tốt HLS và các định dạng iOS hỗ trợ gốc; DASH, RTSP, RTMP và UDP chưa được triển khai ở mốc đầu.
- Chưa ký IPA vì cần Apple Development Team/certificate/provisioning profile của chủ dự án.
- Workflow run `34676835584`, job `103508071797`: tạo project bằng XcodeGen và build ứng dụng cho iPhone/iPad Simulator đều **SUCCESS**.
- Commit build thành công: `281610192cff8013fe0c28571f5cd87a7b69ddf0`.
- Bước tiếp theo: bổ sung icon/hình nền chính thức, kiểm thử phát playlist trên thiết bị thật và cấu hình ký ứng dụng.
