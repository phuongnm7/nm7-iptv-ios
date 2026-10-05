# NM7 IPTV cho iPhone & iPad

Ứng dụng IPTV native cho **iPhone/iPad**, dùng SwiftUI + AVPlayer + MobileVLCKit và custom CENC/ClearKey pipeline.

## Trạng thái hiện tại — 2026-10-05

- **Phiên bản đang phát triển:** 1.0.72
- **Bundle version:** 72
- **Branch:** `fix/ios-1.0.71-real-clearkey-navigation`
- **Mục tiêu mốc này:** sửa toàn bộ đường phát nhóm **Thể thao**, hoàn thiện điều hướng iPhone/iPad và tiếp tục xác thực **DASH/ClearKey CENC**.
- **Nền tảng:** iOS/iPadOS 16+
- **Player:** AVPlayer cho HLS/MP4/FairPlay; MobileVLCKit cho luồng IPTV trực tiếp; custom CENC processor cho ClearKey DASH.
- **Không coi CI xanh là bằng chứng DRM đã chạy trên thiết bị thật.**

### Tiến độ mới nhất

1. **Nhóm Thể thao:** đã xác định nguyên nhân quan trọng ở tầng player: nhiều URL thể thao là HTTP MPEG-TS/direct IPTV, không có đuôi `.ts` và không phải HLS/DASH. iOS AVPlayer không nên là engine đầu tiên cho nhóm này.
2. **Engine routing:** bổ sung phân loại `Channel.prefersVLC`; luồng HTTP/HTTPS trực tiếp không phải HLS/DASH được chuyển thẳng sang MobileVLCKit. Các URL `.ts`, portal `play/live.php`, RTSP/RTMP/UDP/SRT cũng được hỗ trợ.
3. **VLC:** thêm reconnect/continuous HTTP và truyền User-Agent/Referer/Cookie từ playlist.
4. **ClearKey:** real public DASH/CENC smoke test hiện **PASS** trên CI. Điều này xác nhận MPD/segment thật có thể được tải và giải mã theo test pipeline; chưa phải bằng chứng AVPlayer trên iPhone thật đã phát ổn định.
5. **UI/điều hướng:** đã có adaptive iPhone/iPad, edge-swipe mở menu, điều hướng bằng phím mũi tên/Return/Escape và focus channel.
6. **Player UI:** bề mặt VideoPlayer đã được giữ cho cả AVPlayer và custom DASH/ClearKey engine.

## CI hiện tại

Run mới nhất đang xử lý commit:

`91da7a383c4530ad7376366a91416197aa088da0`

Pipeline **NM7 IPTV iOS 1.0.72 SPORTS VLC + CLEARKEY v4** đã chạy qua:
- Install build tools — PASS
- Real public ClearKey DASH/CENC smoke — PASS
- Prepare assets — PASS
- Generate workspace — PASS
- Simulator build — đang chạy/đang xác minh ở thời điểm cập nhật tài liệu

Một run ngay trước đó đã FAIL ở Simulator build do source lúc đó gọi `shouldPreferVLC`/`startVLC` trước khi helper được đưa đầy đủ vào cùng commit. Lỗi này đã được xác định; source hiện tại đã chứa hai helper đó. **Không sử dụng run FAIL cũ để kết luận source hiện tại hỏng.**

## DRM — giới hạn kỹ thuật

- **ClearKey CENC:** app có custom pipeline MPD → fragmented MP4/CENC → decrypt → player.
- **FairPlay:** dùng API native của Apple khi stream cung cấp FairPlay.
- **Widevine/PlayReady:** không được giả định là có CDM native trên iOS. App không thể biến một stream Widevine/PlayReady thành ClearKey chỉ bằng sửa parser.
- Chỉ đánh dấu DRM hoàn thành sau khi có bằng chứng runtime trên iPhone/iPad thật.

## Thể thao — nguyên tắc xử lý

Playlist thể thao hiện được build tự động từ nhiều nguồn. CI của playlist hiện xác nhận các nguồn A/B và `sources/sport-selected.m3u` đều được đọc, với các entry thể thao không có ngày vẫn được giữ lại.

Trong app:
- HLS/DASH → AVPlayer/custom DASH path.
- HTTP MPEG-TS/direct IPTV → MobileVLCKit.
- Có header → truyền header tương ứng sang engine.
- Không chờ AVPlayer 8 giây rồi mới fallback đối với stream đã được xác định ngay từ đầu là direct IPTV.

## Chưa được đánh dấu hoàn thành

- Chưa có xác nhận cuối cùng trên iPhone/iPad thật cho **toàn bộ nhóm Thể thao**.
- Chưa có xác nhận cuối cùng rằng **mọi** stream ClearKey thực tế trong playlist thể thao đều phát được.
- IPA chỉ được công bố khi pipeline build + unit tests + device build + package hoàn tất.

## Quy tắc phát triển

- Không sửa Android để giải quyết lỗi iOS.
- Android là source of truth về chức năng/hành vi.
- Mọi lỗi player phải được khoanh vùng ở URL/format/header/DRM/engine trước khi sửa UI.
- Không dùng synthetic unit test để tuyên bố DRM runtime đã hoàn thành.
- Không phát hành IPA khi CI chưa qua device build/package.

Xem nhật ký chi tiết tại [`PROGRESS.md`](./PROGRESS.md).
