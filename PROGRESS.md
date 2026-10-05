# NM7 IPTV iOS — tiến độ dự án

## 2026-10-05 — Mốc 1.0.72: SPORTS VLC + REAL CLEARKEY

### Trạng thái hiện tại

- Repository: `phuongnm7/nm7-iptv-ios`
- Branch: `fix/ios-1.0.71-real-clearkey-navigation`
- Version source: **1.0.72 / build 72**
- Latest commit: `91da7a383c4530ad7376366a91416197aa088da0`
- Workflow: **NM7 IPTV iOS 1.0.72 SPORTS VLC + CLEARKEY v4**
- Mục tiêu: xử lý triệt để nhóm Thể thao, adaptive navigation iPhone/iPad và xác thực ClearKey bằng dữ liệu thật.

### Đã làm

#### 1. Khoanh vùng lỗi nhóm Thể thao

Không phải toàn bộ kênh thể thao là DASH/DRM. Playlist thể thao hiện chứa nhiều luồng HTTP IPTV/direct MPEG-TS, trong đó URL có thể **không có đuôi `.ts`**. Nếu cứ đưa tất cả vào AVPlayer rồi mới chờ fallback thì trên iOS dễ gặp màn hình đen/stall.

Đã chuyển quyết định engine lên trước khi tạo AVPlayer item:

- HLS → AVPlayer.
- DASH/DRM → custom DASH/CENC hoặc FairPlay tương ứng.
- HTTP/HTTPS direct IPTV → MobileVLCKit.
- `.ts`, `play/live.php`, RTSP, RTMP, UDP, SRT → ưu tiên VLC.
- Truyền User-Agent, Referer, Cookie khi playlist có khai báo.
- VLC bật reconnect/continuous HTTP và network caching thấp hơn đường fallback cũ.

#### 2. ClearKey CENC

Đã có smoke test với MPD/segment ClearKey thật trên CI và bước **Real public ClearKey DASH/CENC smoke = PASS**.

Các sửa parser trước đó gồm:
- `tenc` / KID / IV size / constant IV.
- `trex.default_sample_size` đúng offset.
- absolute moof/fragment base offset.
- `trun`, `senc`, `saiz/saio`.
- nhiều `moof`.
- CENC/CBCS handling.
- merge license headers với channel headers.

### CI mới nhất

Run: **37321133110**

Tại thời điểm cập nhật:
- Install build tools: PASS
- Real public ClearKey DASH/CENC smoke: PASS
- Prepare bundled visual assets: PASS
- Generate workspace: PASS
- Simulator build: đang chạy

Run trước đó: **37320745359 — FAILURE**.

Nguyên nhân run trước đã xác định chính xác:
- `ChannelPlayer.swift:106` thiếu `shouldPreferVLC`
- `ChannelPlayer.swift:107` thiếu `startVLC`

Đó là lỗi build do các commit sửa routing được tách ra không đồng bộ. Source hiện tại đã bổ sung đầy đủ hai helper và workflow đã được sửa lại branch/build-number.

### 3. UI và điều hướng

Đã triển khai:
- tự nhận diện iPhone/iPad;
- layout adaptive;
- edge swipe để mở/đóng sidebar;
- focus channel;
- điều hướng trái/phải/lên/xuống;
- Return để mở/phát;
- Escape để đóng;
- khi đang ở channel đầu hàng, đi trái có thể mở menu;
- PlayerScreen hỗ trợ panel nhóm/kênh trên iPad và chuyển kênh bằng swipe.

### 4. Playlist thể thao

Repo playlist `phuongnm7/Iptv-phuongnm7` có workflow tự động **Update sports auto playlist (multi-source)**.

Run gần nhất:
- Run: `37319902023`
- Kết quả: **SUCCESS**
- Source A: 384 raw / 381 còn hiệu lực
- Source B: 1 undated
- Source C: 80 raw nhưng 80 đã quá hạn theo rule 180 phút
- Source D (`sources/sport-selected.m3u`): 98 undated, được giữ lại

Điểm quan trọng: workflow playlist đã chạy thành công, nên lỗi “tất cả nhóm thể thao không xem được” phải được xử lý tiếp ở **engine phát của iOS và/hoặc từng loại URL**, không được chỉ nhìn vào bước build playlist.

## Việc còn lại — tiêu chí hoàn thành

### P0 — bắt buộc
1. Simulator build PASS.
2. Unit tests PASS.
3. Device Release build PASS.
4. Package IPA PASS.
5. Kiểm tra IPA chứa đúng assets và version 1.0.72/build 72.
6. Kiểm tra trực tiếp các URL thể thao thuộc các loại:
   - HLS
   - DASH
   - HTTP MPEG-TS/direct IPTV
   - URL có User-Agent/Referer/Cookie
7. Kiểm tra ClearKey trên stream thật.
8. Chỉ sau đó mới đánh dấu **DONE**.

### Không được làm

- Không tuyên bố “đã sửa xong” chỉ vì CI xanh.
- Không thay tất cả stream thể thao bằng một URL khác chỉ để làm cho có hình.
- Không bỏ qua header/token của nguồn.
- Không biến Widevine/PlayReady thành ClearKey bằng cách đoán.
- Không phát hành IPA trước khi device build/package pass.

## Lịch sử

### 1.0.71 — REAL CLEARKEY + adaptive navigation
- Cải thiện CENC parser và real ClearKey smoke.
- Adaptive iPhone/iPad navigation.
- Edge-swipe sidebar.
- Keyboard/remote navigation.
- Player routing cho DASH/ClearKey.

### 1.0.70 — DRM + Web UI parity
- Web-like home layout.
- VTV backup HLS mapping.
- CENC multi-moof/trun/tfhd improvements.
- Cache version bump.

### 1.0.69 — Android baseline
- Android 1.0.69 làm source of truth.
- SwiftUI iOS/iPadOS 16+.
- AVPlayer + MobileVLCKit.
- M3U parser, groups, favorites, recents, voice search, source management.

## Kết luận trạng thái

**IN PROGRESS — chưa hoàn thành.**

Mốc 1.0.72 đã chuyển từ cách “AVPlayer trước, VLC fallback sau” sang **chọn đúng engine ngay từ đầu cho direct sports streams**, đồng thời real ClearKey smoke đã PASS. Chưa được coi là hoàn thành cho tới khi pipeline build/test/package và kiểm tra phát thực tế trên thiết bị đạt yêu cầu.
