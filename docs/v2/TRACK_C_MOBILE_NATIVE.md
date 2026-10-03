# Track C — Phần native của app và nối API thật

Đọc [README.md](README.md), [DECISIONS.md](DECISIONS.md) và [API_CONTRACT.md](API_CONTRACT.md) trước.

**Mục tiêu:** viết bản thật cho các interface mà Track A tạo ở `lib/platform/contracts/` và cho các repository gọi API mới, rồi nối vào app qua `bootstrap.dart`. Track C không dựng màn hình và không thêm chuỗi hiển thị.

**Phạm vi file:** `apps/mobile/lib/platform/**` (trừ `contracts/` và `fakes/` là của Track A), `apps/mobile/lib/features/**/data/remote/**` và `**/data/repositories/api_*`, `apps/mobile/lib/app/bootstrap.dart`, `apps/mobile/pubspec.yaml` và `pubspec.lock`, `apps/mobile/android/**`, `apps/mobile/ios/**`, `apps/mobile/tool/**`, `.github/workflows/mobile-*.yml`, test có tiền tố `v2c_`. **Không sửa `lib/l10n/*.arb`, màn hình, router, hay `savestream_app.dart`.**

## Tiến độ

- [ ] C0 — Plugin và khung native
- [ ] C1 — Repository gọi API V2
- [ ] C2 — Thử nghiệm kỹ thuật ghi trên máy (**dừng chờ duyệt**)
- [ ] C3 — Ghi trên máy cho Android
- [ ] C4 — Ghi trên máy cho iOS
- [ ] C5 — Trình phát, thư viện file, chia sẻ, tải bản cloud
- [ ] C6 — Mua trong app
- [ ] C7 — Quảng cáo và xin đồng ý
- [ ] C8 — Push và deep link (**cần dự án Firebase**)
- [ ] C9 — Hoàn thiện để phát hành

## Kiểm tra (chạy trong `apps/mobile` trước khi mở PR)

```bash
flutter pub get --enforce-lockfile          # sau khi đổi pubspec: chạy `flutter pub get` rồi commit pubspec.lock
bash tool/generate_native_assets.sh         # cần Python 3 và thư viện Cairo
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib/app lib/core lib/features lib/l10n/l10n.dart test
flutter analyze --fatal-infos
flutter test
flutter build appbundle --release --dart-define=APP_ENV=production --dart-define=MOBILE_EXTERNAL_CHECKOUT_ENABLED=false
bash tool/phase17_release_audit.sh
```

CI phải xanh: `flutter-checks` (có build Android App Bundle), `ios-release-compile` (biên dịch iOS cho simulator), `mobile-backend-e2e`.

## Quy tắc chung cho mọi phase của Track C

1. **Bản thật đứng sau interface của Track A.** Không đổi chữ ký interface; cần đổi thì báo Track A.
2. **Nối vào app chỉ qua `bootstrap.dart`**, bằng tham số `extraOverrides` của `SaveStreamApp` (Track A tạo ở A0). Test và bản xem trước vẫn dùng bản fake.
3. **Mỗi plugin mới phải biên dịch được trên cả Android và iOS trong CI mà không cần tài khoản hay khoá thật.** Dùng mã thử nghiệm chính thức của nhà cung cấp cho bản không phải production. Khoá thật truyền qua `--dart-define` hoặc file cấu hình được gitignore.
4. **Không commit khoá, keystore, `google-services.json`, `GoogleService-Info.plist`** hay bất kỳ thông tin xác thực nào.
5. **Chuỗi hiển thị trong phần native** (thông báo "đang ghi" của Android, nhắc quay lại app của iOS): lấy từ các key `native*` Track A đã tạo trong ARB, truyền từ Dart xuống native. Không viết cứng trong Kotlin hay Swift.
6. **Quyền hệ thống:** mỗi quyền thêm vào `AndroidManifest.xml` hoặc `Info.plist` phải có lý do ghi trong PR, và chuỗi mô tả quyền của iOS phải có cả EN và VI (`InfoPlist.strings`).
7. **Test:** logic thuần Dart có unit test với bản giả của kênh native; phần chỉ chạy được trên thiết bị thật thì ghi kịch bản kiểm tay vào `apps/mobile/MOBILE_RELEASE.md`.
8. Mỗi phase kết thúc bằng việc chạy app trên ít nhất một máy ảo Android và ghi kết quả vào PR. Phần iOS cần máy Mac có Xcode; nếu không có, nói rõ "chưa chạy trên iOS" trong PR.

---

## C0 — Plugin và khung native

**Phụ thuộc:** A0 **đã merge vào `main`** (PR còn mở thì chưa bắt đầu).

1. Thêm plugin (chọn phiên bản ổn định mới nhất tương thích Flutter 3.47, khoá trong `pubspec.lock`): `connectivity_plus`, `path_provider`, `permission_handler`, `device_info_plus`, `package_info_plus`, `share_plus`, `wakelock_plus`, `video_player`, `in_app_purchase`, `google_mobile_ads`.
   - **Chưa thêm** `firebase_core` và `firebase_messaging` (để C8, vì cần file cấu hình Firebase).
2. `google_mobile_ads` cần mã ứng dụng trong manifest và `Info.plist` nếu không app sẽ dừng khi khởi động: đặt qua biến build, mặc định là **mã ứng dụng thử nghiệm chính thức của AdMob**.
3. Viết bản thật cho `ConnectivityService` và `DeviceInfoService`; `deviceId` sinh một lần và lưu bằng `flutter_secure_storage`.
4. Nâng `minSdk` nếu plugin yêu cầu; cập nhật `flutter_launcher_icons.min_sdk_android` cho khớp.
5. Cập nhật `tool/phase17_release_audit.sh` và, nếu cần, workflow để kiểm tra tiếp tục đúng. Đổi tên script thành `tool/release_audit.sh` và sửa nơi gọi.
6. Kiểm tra kích thước bản build và ghi vào PR.

Định nghĩa xong: CI xanh, app khởi động được trên máy ảo Android với toàn bộ plugin, hành vi không đổi.

---

## C1 — Repository gọi API V2

**Phụ thuộc:** C0, **B0 đã merge** (code theo `docs/openapi.yaml`). Chạy thật được sau khi B1 merge.

Track A có thể đã sửa tối thiểu vài file ánh xạ trong `data/remote/` khi thêm trường vào model (ngoại lệ số 1 trong README). Rebase lên `main` trước khi bắt đầu và xây tiếp trên các sửa đổi đó, không viết đè.

1. Viết `Api…Repository` cho: `EntitlementRepository`, `AppStatusRepository`, `DeviceRepository`, và mở rộng `ApiWatchRepository` với `notify_on_live`, `auto_record_state`, lỗi `WATCH_LIMIT_REACHED` và `PLAN_REQUIRED`.
2. Mở rộng `ApiRecordingRepository`: trạng thái `waiting_for_cloud_slot`, `missed_no_cloud_slot`, trường `expires_at`, `minutes_charged`, `queue_position`. Trạng thái lạ không làm hỏng danh sách.
3. Mở rộng tuỳ chọn thông báo và loại thông báo theo hợp đồng mục 7.
4. Ánh xạ mã lỗi mới vào `ApiException` theo `error.code`, không theo câu chữ.
5. Nối vào `bootstrap.dart`. Endpoint trả `501` (backend chưa làm xong): repository rơi về giá trị mặc định an toàn (coi là Free, không giới hạn sai) và không làm app dừng.
6. Test bằng Dio giả theo mẫu `test/api_client_test.dart`: giải mã đúng, mọi mã lỗi mới, phân trang.
7. Cập nhật test E2E `test/backend_connectivity_e2e_test.dart` khi B1 đã merge.

---

## C2 — Thử nghiệm kỹ thuật ghi trên máy (dừng chờ duyệt)

**Phụ thuộc:** C0. **Đây là phần rủi ro kỹ thuật lớn nhất của V2. Phase này không tạo tính năng; nó tạo bằng chứng và một đề xuất. Xong thì dừng, báo chủ repo, không làm C3.**

Câu hỏi phải trả lời bằng thử nghiệm thật trên thiết bị:

1. **Định dạng luồng:** backend trả luồng FLV hay HLS cho TikTok LIVE (xem `backend/src/engine`, `backend/ENGINE.md`)? Địa chỉ sống bao lâu, cần header gì?
2. **Cách ghi:** tải luồng thẳng xuống file bằng HTTP (FLV), hay tải từng đoạn HLS rồi ghép. Đo: CPU, pin, dung lượng mỗi phút.
3. **Phát lại:** file ghi được có phát bằng `video_player` trên Android (ExoPlayer) và iOS (AVPlayer) không? iOS không phát FLV; nếu luồng là FLV thì cần chuyển gói sang MP4 trên máy. Đánh giá các cách chuyển gói không chuyển mã và giấy phép của thư viện.
4. **Android chạy nền:** Foreground Service loại `dataSync` hay `mediaPlayback` có giữ được phiên ghi dài không; hành vi khi bị hệ thống hoặc hãng máy dừng; giới hạn của Android 14 và 15 với foreground service.
5. **iOS chạy nền:** xác nhận thực tế ghi dừng sau bao lâu khi app vào nền; có cách hợp lệ nào kéo dài không.
6. **Khôi phục:** app bị dừng đột ngột thì file dở dang có phát được không, cần ghi theo đoạn như thế nào để mất ít nhất.
7. **Chính sách store:** rà quy định hiện hành của Google Play và App Store về app tải nội dung từ nền tảng bên thứ ba; ghi lại rủi ro bị từ chối.

Sản phẩm của phase:

- `docs/v2/SPIKE_LOCAL_RECORDING.md`: kết quả đo, phương án đề xuất, phương án dự phòng, những gì **không** làm được, ước lượng công cho C3 và C4.
- Code thử nghiệm đặt trong `apps/mobile/tool/spike_local_recording/` (không nối vào app, không vào bản build).

Chủ repo đọc và duyệt phương án rồi mới làm C3.

---

## C3 — Ghi trên máy cho Android

**Phụ thuộc:** C2 đã được duyệt, A3 đã merge, B4 đã merge (để chạy thật).

1. Bản thật của `LocalRecorder` cho Android theo phương án đã duyệt: Foreground Service với thông báo "đang ghi" (kênh mức thấp, có nút Dừng; bấm Dừng thì dừng và hoàn tất file, không mở app).
2. `ApiLocalRecordingRepository`: bắt đầu, gia hạn, kết thúc, danh sách, xoá.
3. **Lease:** bộ ghi chạy theo `granted_seconds` đã cấp, không phụ thuộc phiên đăng nhập. Phiên hết hạn giữa chừng thì vẫn ghi tiếp và không xoá đoạn nào.
4. Mất kết nối tới nguồn: trạng thái `reconnecting`, thử lại có giới hạn, không tính thời gian không ghi được.
5. Bộ nhớ: cảnh báo khi sắp đầy; dưới 250 MB thì dừng an toàn và hoàn tất file.
6. Khôi phục khi mở lại app sau khi bị dừng: phát hiện phiên dở, ghép lại phần đã lưu, báo `recovered` hoặc `partial`, gọi `finish` lên backend.
7. File lưu trong thư mục riêng của app, gắn `user_id`; giữ lại sau khi đăng xuất và chỉ hiện với đúng tài khoản.
8. Kiểm tra trạng thái tối ưu pin và mở trang cài đặt hệ thống tương ứng.
9. Kịch bản kiểm tay trên thiết bị thật ghi vào `MOBILE_RELEASE.md`: ghi 10 phút khi khoá màn hình, chuyển app, mất mạng 30 giây, hết bộ nhớ, bị dừng đột ngột.

---

## C4 — Ghi trên máy cho iOS

**Phụ thuộc:** C3. Cần máy Mac có Xcode và thiết bị iOS thật.

1. Bản thật của `LocalRecorder` cho iOS. Giữ màn hình sáng (`wakelock_plus`) chỉ khi đang ghi ở tiền cảnh.
2. Khi app vào nền: gửi thông báo cục bộ nhắc quay lại app (dùng key `nativeKeepAppOpenReminder*`), và xử lý phiên bị gián đoạn theo kết quả C2.
3. Khôi phục và báo trạng thái giống C3.
4. Chuỗi mô tả quyền trong `InfoPlist.strings` (EN, VI).
5. Nếu không có môi trường iOS: dừng, báo chủ repo, không merge code iOS chưa chạy thử.

---

## C5 — Trình phát, thư viện file, chia sẻ, tải bản cloud

**Phụ thuộc:** C3, A4 đã merge.

1. Nối `video_player` vào `SsVideoSurface` của Track A: phát file trên máy và phát bản cloud qua link tải có thời hạn (xin link mới cho mỗi lần phát, không lưu lại).
2. Chỉ mục file trên máy: đối chiếu file thật với metadata từ backend; phát hiện file bị mất hoặc di chuyển.
3. Tải bản cloud về máy với tiến độ theo byte thật, tiếp tục được khi gián đoạn, kiểm tra dung lượng trống trước khi tải.
4. Bản thật của `ShareService` qua `share_plus`. Chia sẻ bản cloud: tải file tạm rồi mở bảng chia sẻ hệ thống, xoá file tạm sau đó.
5. Xoá: file trên máy và gọi `DELETE /v1/local-recordings/{id}`.

---

## C6 — Mua trong app

**Phụ thuộc:** C1, A5 đã merge. Chạy thật cần B5 đã merge và tài khoản store.

1. Bản thật của `PurchaseService` bằng `in_app_purchase`: tải sản phẩm theo mã trong `GET /v1/billing/packages`, mua, lắng nghe luồng giao dịch, khôi phục.
2. `ApiStoreRepository`: gửi hoá đơn lên `POST /v1/billing/store-purchases`. **Chỉ hoàn tất giao dịch với store (`completePurchase`) sau khi backend trả `credited`.** Giao dịch chưa gửi được thì lưu lại và gửi lại khi mở app.
3. Phân biệt rõ: người dùng huỷ, thất bại, đang chờ (ví dụ chờ phụ huynh duyệt).
4. Sau khi `credited`: làm mới entitlement, kênh và Home.
5. Giá hiển thị luôn lấy từ store.
6. Gỡ cờ `MOBILE_EXTERNAL_CHECKOUT_ENABLED` và mã liên quan khỏi `AppConfig`, sau khi Track A đã xoá màn Billing cũ (A5). Cập nhật script audit và workflow tương ứng.
7. Không có tài khoản store thì không thử mua thật được: hoàn thành code và test với bản giả của plugin, ghi kịch bản thử với tài khoản sandbox vào `MOBILE_RELEASE.md`, nói rõ trong PR là chưa thử trên store.

---

## C7 — Quảng cáo và xin đồng ý

**Phụ thuộc:** C1, A3 và A7 đã merge. Chạy thật cần B4 đã merge.

1. Bản thật của `AdsService` bằng `google_mobile_ads`: banner thích ứng cho các vị trí Track A đã đặt `SsBannerAdSlot`, và quảng cáo thưởng có xác minh phía máy chủ (truyền `ssv_user_id` và `ssv_custom_data` từ `POST /v1/rewards`).
2. Không có quảng cáo để hiện: ẩn hẳn vị trí banner, không để khoảng trống.
3. **Xin đồng ý:** nền tảng xin đồng ý của Google (UMP) theo khu vực; trên iOS thêm lời nhắc theo dõi của hệ thống (ATT) chỉ khi cần. Trạng thái trả qua `AdsService.consentState`.
4. Pro: không khởi tạo SDK quảng cáo, không xin đồng ý.
5. Mặc định dùng mã đơn vị quảng cáo thử nghiệm chính thức; mã thật truyền qua `--dart-define` cho bản production.
6. Không tải quảng cáo trên màn đang ghi, màn mua, trình phát, và trước khi người dùng có kênh đầu tiên.

---

## C8 — Push và deep link (cần dự án Firebase)

**Phụ thuộc:** C1, A6 đã merge, B3 đã merge. **Chủ repo phải cung cấp dự án Firebase trước; chưa có thì dừng ở đây và làm C9 trước.**

1. Thêm `firebase_core` và `firebase_messaging`. File cấu hình Firebase **không commit**: CI dùng file giả đủ để biên dịch; file thật đặt lúc build phát hành. Ghi cách làm vào `MOBILE_RELEASE.md`.
2. Bản thật của `PushService`: quyền thông báo (Android 13 trở lên và iOS), token, làm mới token, đăng ký thiết bị qua `PUT /v1/me/devices/{device_id}`, gỡ khi đăng xuất.
3. Kênh thông báo Android: "Creator LIVE" và "Bản ghi", tên lấy từ key `nativePushChannel*`.
4. **Deep link:** chạm vào push mở đúng màn theo `resource_type` và `resource_id`. Thêm scheme `savestream://` cho các đường dẫn mới (hiện mới có đường quay về từ thanh toán).
5. App đang mở: hiện thông báo trong app thay cho push hệ thống.

---

## C9 — Hoàn thiện để phát hành

**Phụ thuộc:** các phase trước đã merge (C8 có thể còn chờ Firebase).

1. Rà toàn bộ quyền trong manifest và `Info.plist`, gỡ quyền không dùng.
2. Cấu hình rút gọn mã (R8) và quy tắc giữ lại cho các plugin; xác nhận bản release chạy đúng.
3. Cập nhật `apps/mobile/MOBILE_RELEASE.md`: toàn bộ `--dart-define` cần cho bản production, cách ký, kịch bản kiểm tay đầy đủ, danh sách dữ liệu thu thập để khai báo trên store (quảng cáo, mã thiết bị, push token, lịch sử mua).
4. Cập nhật `apps/mobile/README.md` cho đúng kiến trúc V2.
5. Mở rộng workflow E2E với backend cho các luồng mới chạy được không cần thiết bị: entitlement, giới hạn kênh, hàng chờ slot.
6. Nâng phiên bản app lên `2.0.0+<số build>`.
7. Viết `docs/v2/RELEASE_CHECKLIST_MOBILE.md`: những việc chủ repo phải tự làm (tài khoản store, tạo sản phẩm mua trong app, tài khoản quảng cáo, Firebase, keystore, đối chiếu chính sách store).
