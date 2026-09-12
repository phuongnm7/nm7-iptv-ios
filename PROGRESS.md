# NM7 IPTV iOS — tiến độ dự án

## Mốc 0.2.0 — điều khiển player và giọng nói

- Thêm chuyển kênh trước/sau trong cùng nhóm bằng nút hoặc vuốt ngang trên video.
- Thêm trạng thái đang tải và hộp thoại lỗi phát, có nút thử lại.
- Thêm tìm và mở kênh bằng giọng nói tiếng Việt ở màn hình chính và trong player.
- Chuẩn hóa câu lệnh như “mở kênh”, “xem kênh”, “phát kênh”, bỏ dấu và đối chiếu tên gần đúng.
- Thêm quyền Microphone/Speech Recognition và unit test bộ ghép tên kênh.
- Tách quản lý AVPlayer để theo dõi buffering/lỗi và giữ bộ đệm 12 giây.
- Version dự kiến: 0.2.0 (build 2). Chờ workflow Xcode xác nhận.


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
