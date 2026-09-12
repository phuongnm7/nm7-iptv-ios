# NM7 IPTV iOS — tiến độ dự án

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
- Cần xác nhận workflow build PASS trước khi chuyển sang kiểm thử thiết bị thật.
