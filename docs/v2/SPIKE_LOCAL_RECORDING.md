# C2 — Local recording technical spike

Status: code complete. By owner decision on 2026-10-04, real-device validation is deferred and will be run against the final APK after the app is complete. This document therefore does not claim device evidence yet; the checklist below remains the acceptance checklist for that final validation.

## Slice 1 — Direct stream download probe

### What the current backend proves

- `backend/src/core/tiktok_api.py::get_live_url()` prefers the highest-quality
  `main.flv` URL from TikTok's `live_core_sdk_data.pull_data.stream_data`.
- The legacy fallback also prefers `flv_pull_url` variants before falling back
  to RTMP.
- `download_live_stream()` performs a streaming HTTP GET and yields 4096-byte
  chunks to the recording engine.
- The backend deliberately uses its browser-impersonated `HttpClient` for the
  stream download. Its source comment says TikTok's pull CDN blocked plain
  `requests` because it lacked the expected TLS fingerprint and produced
  zero-byte recordings.

This is strong evidence that the first mobile experiment must test FLV over
direct HTTP, and must explicitly record whether Dart/OS networking is accepted
by the CDN. It is not evidence that Dart `HttpClient` will work.

The repository does **not** currently establish:

- how long a TikTok pull URL remains valid;
- which request headers, cookies, or TLS fingerprint are strictly required on
  Android or iOS;
- whether the same URL can be resumed after an interrupted connection.

Those points require a real-device/live-stream run.

### Probe added for the experiment

`apps/mobile/tool/spike_local_recording/` contains an isolated Dart CLI. It is
not wired into the Flutter app or release build.

Example:

```bash
dart run tool/spike_local_recording/bin/record_stream.dart \
  --url '<live-pull-url>' \
  --output build/c2/sample.flv \
  --seconds 60
```

Optional headers can be supplied repeatedly:

```bash
--header 'User-Agent:...' --header 'Referer:https://www.tiktok.com/'
```

The probe records:

- HTTP status;
- transport classification (FLV/HLS/RTMP/unknown);
- bytes written;
- elapsed time;
- bytes/second;
- MiB/minute;
- response content type.

A non-2xx response or a zero-byte response remains measurable evidence and
causes the CLI to exit non-zero.

### Next device evidence

Run the same pull URL on Android first, then iOS, with no custom headers and
then only with headers justified by captured backend behavior. Record whether
the CDN rejects the native Dart TLS/client fingerprint. Do not add bypass or
production integration in C2.


## Checklist kiểm thử thiết bị thật cho Thanh

Mục tiêu: thu bằng chứng để chốt C2; không tích hợp vào app production.

### Thiết bị

- Android chuẩn: Pixel 7/8 chạy Android 15.
- Android OEM: Samsung Galaxy A54/S23 (hoặc máy Samsung tương đương) chạy Android 14 hoặc 15 để kiểm tra giới hạn nền của hãng.
- iOS: iPhone 13/14/15 thật, ưu tiên máy đang chạy iOS 18 trở lên. Nếu chỉ có một iPhone thì dùng máy đó và ghi rõ model + phiên bản iOS.

### Mỗi lượt test cần ghi

- model máy, phiên bản OS, mức pin đầu/cuối, thời lượng test;
- URL loại gì (FLV/HLS/RTMP), HTTP status, có cần header/cookie nào không;
- URL còn dùng được sau 1, 5, 10 và 30 phút hay không;
- bytes ghi được, MiB/phút, dung lượng file cuối;
- CPU trung bình/đỉnh nếu công cụ hệ thống xem được;
- file có phát được không, bằng player nào; nếu phải remux thì thời gian remux và có re-encode hay không;
- kết quả khi chuyển app, khóa màn hình, mất mạng 30 giây, force-stop/crash;
- file dở có phục hồi/phát được không và mất tối đa bao nhiêu giây dữ liệu.

### Trình tự ngắn

1. Lấy một TikTok LIVE đang phát và pull URL mà backend đang dùng.
2. Chạy probe 10 phút ở foreground, không thêm header trước; nếu thất bại mới thử đúng header/cookie backend đang dùng.
3. Với cùng URL, kiểm lại ở mốc 1/5/10/30 phút để đo lifetime.
4. Phát file vừa ghi bằng player hệ thống/`video_player`; trên iOS ghi rõ FLV có phát trực tiếp hay phải remux MP4.
5. Android: chạy tiếp 10 phút khi chuyển app và khóa màn hình; lặp lại trên Pixel và Samsung.
6. iOS: bắt đầu ghi ở foreground, chuyển nền/khóa màn hình và ghi thời điểm stream thực sự dừng.
7. Mất mạng 30 giây rồi nối lại; sau đó force-stop/crash giữa lúc ghi và kiểm tra file dở bằng FLV recovery probe.
8. Ghi kết quả trực tiếp vào bảng/kết luận của tài liệu này; chưa duyệt C2 cho tới khi các mục trên có số liệu thật.


## Deferred device validation decision

C2 code is considered complete for repository progress. Real-device measurements are intentionally deferred to the final APK validation pass after all implementation phases finish. Until that pass is recorded here, CPU, battery, background behavior, playback/remux compatibility, URL lifetime, and crash-recovery behavior remain unverified on real Android/iOS devices.
