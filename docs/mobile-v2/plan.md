# SaveStream Android v2: kế hoạch Pha 0 (audit, kiến trúc, backend, checklist Google Play)

Trạng thái: **tài liệu, chưa code**. Ngày 2026-10-22. Code UI chỉ bắt đầu khi QA gửi danh sách artboard
chốt từ Claude Design (canvas "SaveStream Android App", bản nháp 8 màn).

Mục tiêu v2: app Android tiếng Anh trên Google Play. App **chỉ là dashboard và trình phát** gọi API
hiện có. Mọi việc ghi chạy trên cloud của SaveStream. Trong app không có code scrape hay tải luồng
LIVE. Người dùng chỉ ghi được **kênh của chính mình đã xác minh**.

---

## 1. Audit app mobile v1 (`apps/mobile`)

Quy mô v1:

- Flutter, phiên bản `2.0.0+8`.
- `lib/` có 258 file Dart, khoảng 33k dòng. Test có 45 file (156 unit + 90 widget).
- Kotlin native khoảng 1,2k dòng.
- Kiến trúc: Riverpod 3, go_router (54 route), Dio, `flutter_secure_storage`, ARB l10n EN/VI.
- Chất lượng nền tốt (repository interface, mock/fake, idempotency key, typed error, HTTPS bắt buộc).
  Nhưng màn hình rất to (700–1.200 dòng) và có provider trùng (`v2_foundation`).

### 1.1 Vi phạm / rủi ro chính sách

Mức: 🔴 chặn phát hành · 🟠 phải sửa trước khi nộp · 🟡 nên sửa.

| # | Mức | Vấn đề | Bằng chứng | Xử lý v2 |
|---|---|---|---|---|
| 1 | 🔴 | **Ghi LIVE trên thiết bị.** Foreground service tải trực tiếp luồng FLV/HLS về máy, kèm tự kết nối lại, khôi phục sau crash và bắt tắt tối ưu pin. | `android/.../LocalRecordingService.kt` (874 dòng; `startForeground` :59/:74, OkHttp tới `streamUrl` :218-224, ghi file :243); `MainActivity.kt` (channel `savestream/local_recording*`, mở cài đặt pin :220); `lib/features/local_recordings/**` (~20 file); `lib/platform/android_local_*` | **Xoá toàn bộ** |
| 2 | 🔴 | **Giả User-Agent trình duyệt**. Client chuyển tiếp header do server cấp (Referer/Cookie) tới CDN của TikTok. | `LocalRecordingService.kt:222`, `:707-708`; `api_local_recording_repository.dart:158-176` (server trả `stream.url/headers`) | Xoá. Backend ngừng cấp URL luồng thô cho client (xem §3.6) |
| 3 | 🔴 | Foreground service kiểu `dataSync` dùng để bắt luồng: sai mục đích khai báo FGS. | `AndroidManifest.xml:3-4`, `:43-46` | Bỏ `FOREGROUND_SERVICE*` và `<service>` |
| 4 | 🔴 | **Theo dõi kênh công khai bất kỳ** bằng username/URL. Chỉ có ô tự cam kết "I own…". Copy kiểu "Monitor a TikTok creator", "Add up to 3 TikTok creators", "Douyin · Coming soon". | `add_channel_screen.dart`, `add_first_creator_screen.dart`, `api_watch_repository.dart:17` (`/v1/live-status`); `app_en.arb:212-216, 526, 533-534, 566-567, 701-705` | Chỉ thêm **kênh của mình**, bắt buộc **xác minh mã trong bio** trước khi ghi (§3.1). Viết lại copy |
| 5 | 🟠 | Rewarded ads chỉ để mở phút ghi trên máy hoặc slot thứ 2. Banner đặt ở Home, Channels và Library. Ad unit ID production hardcode. | `lib/platform/google_mobile_ads_service.dart:48-63` (ID), `:181-191` (SSV); `home_screen.dart:451`, `channels_screen.dart:347`, `recordings_screen.dart:639`; `build.gradle.kts:11-13` | Giữ **rewarded tự nguyện +5 phút cloud**, verify phía server (§3.3). Banner chỉ còn **một chỗ: cuối Home**, chỉ cho tài khoản chưa từng mua (`entitlement.ads.show_banners`); bỏ banner ở Channels và Library (§4.4, §6 câu 3). ID lấy từ build config |
| 6 | 🟠 | `firebase-analytics` thêm ở tầng native (tự thu thập, có AD_ID) nhưng **không khai báo** trong danh mục dữ liệu. | `build.gradle.kts:77`; `MOBILE_RELEASE.md:227-238` | Bỏ. Nếu cần đo thì dùng sự kiện server-side đã có (PostHog) |
| 7 | 🟠 | Nút "Continue with Apple" hiện cả trên Android. Có entitlement Sign in with Apple, ATT. Có màn iOS riêng. | `social_auth_buttons.dart:30-35`; `Info.plist:50-51`; `ios_recording_*_screen.dart` | Android v2: chỉ Email + Google. iOS để sau |
| 8 | 🟠 | Repo checkout web (PayPal) còn trong code, tuy chưa nối UI. Nếu lỡ nối sẽ vi phạm Payments policy của Play. | `lib/features/billing/data/repositories/api_billing_repository.dart:49, :90`; `features/credits/**` | Xoá khỏi app. Chỉ dùng Google Play Billing |
| 9 | 🟠 | Chữ "TikTok" trong UI (14 key ARB + hardcode). Fallback "TikTok creator". | `app_en.arb` (14 dòng); `add_channel_screen.dart:61, :306`; `add_first_creator_screen.dart:185`; `watch_api_models.dart:375` | Chỉ dùng danh nghĩa mô tả ("your TikTok username"), không dùng logo hay màu. Có câu "not affiliated" (§4.6) |
| 10 | 🟡 | "Download to device" và chia sẻ file ghi: kênh phát tán nội dung bên thứ ba. | `cloud_artifact_downloader.dart`; `cloud_recording_share_coordinator.dart`; `app_en.arb:1593` | Giữ được khi chỉ còn kênh đã xác minh (nội dung của chính người dùng). Bàn ở §5 |
| 11 | 🟡 | Dependency chết `permission_handler`, `wakelock_plus`. `okhttp` và `work-runtime` chỉ phục vụ recorder/ads. | `pubspec.yaml`; `build.gradle.kts:78-83` | Bỏ |
| 12 | 🟡 | Đăng ký trên mobile **không bắt đồng ý 18+/Terms/AUP** (backend chỉ bắt với `client_type=web`). | backend `api/routes/auth.py:91`, `application/identity/service.py:471` | Backend bắt consent cho mobile. App có checkbox giống web |
| 13 | 🟡 | `/dev/components` luôn được đăng ký route (chỉ ẩn lối vào). | `app_router.dart:390-395` | Chỉ đăng ký ở build debug |

Không tìm thấy:

- Scrape TikTok phía client: không gọi tiktok.com/webcast, không msToken/X-Bogus, không parse HTML.
- Logo hay màu TikTok (icon là chữ "S" indigo riêng).
- Quyền nguy hiểm: SYSTEM_ALERT_WINDOW, QUERY_ALL_PACKAGES, RECORD_AUDIO, CAMERA, storage, location.
- Cờ "review mode" hay remote config đổi tính năng. Chỉ có `/v1/app/status` (phiên bản tối thiểu, bảo trì).
- Ads interstitial hay app-open.

### 1.2 Quyền Android hiện tại → v2

| Quyền | Nguồn | v2 |
|---|---|---|
| INTERNET | manifest | Giữ |
| POST_NOTIFICATIONS | manifest | Giữ (push "LIVE started / recording ready") |
| FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC | manifest | **Bỏ** |
| `c2dm.RECEIVE`, WAKE_LOCK, ACCESS_NETWORK_STATE | firebase_messaging | Giữ |
| `com.android.vending.BILLING` | in_app_purchase | Giữ |
| `com.google.android.gms.permission.AD_ID`, ACCESS_ADSERVICES_* | google_mobile_ads, firebase-analytics | Giữ (rewarded + banner). AD_ID do SDK Google Mobile Ads tự merge; khai báo Advertising ID trong Data safety (§4.2). Bỏ firebase-analytics |
| RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE (merge từ work-runtime) | workaround ads | Bỏ; dùng `tools:node="remove"` nếu SDK còn kéo vào |

Kiểm tra lại bằng merged manifest của AAB release (`./gradlew :app:processReleaseManifest`) trước khi nộp.

### 1.3 Tái dùng hay viết lại

**Tái dùng gần như nguyên (khoảng 40–50% `lib/`):**

- `lib/core/api/**`: Dio, interceptor auth/refresh, retry, idempotency, request id, SSE.
- `core/config`, `core/storage`.
- `features/auth/**`: email, Google, secure refresh store, session manager, delete account. Bỏ Apple trên Android.
- Model và repository: watches, recordings (artifacts, download-url, SSE events), entitlement, devices, notification preferences, app_status.
- Push: `firebase_push_service`, `push_token_registration_coordinator`, channel thông báo trong `MainActivity`.
- Store IAP: `in_app_purchase_service.dart`, `features/store/**`. Đã verify phía server và có retry queue.
- Player mạng: `video_player_ss_controller.dart`, `ss_video_surface.dart`. Bỏ `flv_timestamp_normalizer` nếu chỉ phát MP4 cloud.
- Hạ tầng test (fakes, harness), l10n pipeline (chỉ còn EN), CI `flutter analyze --fatal-infos`.

**Viết lại (theo artboard Claude Design):**

- Toàn bộ tầng presentation: 8 màn trong bản nháp (Welcome/Sign in, Home, Add channel + verify, Channel, Recordings, Player, Credits, Settings & legal) và onboarding ngắn.
- Theme theo design system mới.
- Chia nhỏ màn, gộp provider trùng.

**Xoá:**

- `LocalRecordingService.kt`, `LocalRecordingEventBus.kt`, `RecordingPlatformActionEventBus.kt`, các channel recorder/pin trong `MainActivity.kt`.
- `<service>`, quyền FGS, `okhttp`, keep rule proguard.
- `lib/features/local_recordings/**`, `lib/platform/android_local_*`, `recording_platform_service*`, `flv_timestamp_normalizer` (nếu không cần), `features/rewards/**` (viết lại cho cloud reward).
- `features/billing/**`, `features/credits/**` (checkout web).
- `tool/spike_local_recording/**`.
- Banner ở Channels và Library (chỉ giữ banner cuối Home, §4.4), hardcode ad ID, `firebase-analytics`, `permission_handler`, `wakelock_plus`, `work-runtime`.
- Màn iOS-only và onboarding local/cloud/pin.

---

## 2. Kiến trúc v2

```
Android app (Flutter)                 SaveStream API (FastAPI, có sẵn)        Cloud
─────────────────────                 ────────────────────────────────        ─────
Auth (email/Google→Firebase ID token) ─► /v1/auth/*  (refresh token trong body)
Dashboard (kênh, trạng thái LIVE)      ─► /v1/watches, /v1/me/entitlement
Thêm kênh + xác minh bio               ─► /v1/channel-verifications  (MỚI)   ─► kiểm tra bio từ server
Bản ghi, trình phát                    ─► /v1/recordings, /v1/artifacts/{id}/download-url ─► R2/Media Worker (URL ký)
Mua giờ (Play Billing)                 ─► /v1/billing/store-purchases ─► Google Play Developer API
Xem quảng cáo +5 phút (AdMob SSV)      ─► /v1/rewards (purpose mới) ◄── AdMob SSV callback
Push (FCM)                             ─► /v1/me/devices/{id}  ◄── FCM HTTP v1
Xoá tài khoản                          ─► DELETE /v1/me  (+ trang web /delete-account)
                                       Recorder workers (blue/green, drain) ghi LIVE trên server
```

Nguyên tắc:

- **Không có code bắt luồng hay scrape trên client.** App không nhận URL luồng LIVE. Chỉ nhận URL
  ký của **file đã ghi xong** (MP4) để phát hoặc tải.
- App không gọi bất kỳ domain TikTok nào. Hiển thị avatar bằng URL cache của SaveStream (`/v1/public/creator-avatars/...`).
- Mọi số liệu (gói, giờ, giá hiển thị, giới hạn quảng cáo) lấy từ API hoặc Play. Không hardcode
  (giống web: runtime settings).
- **Stack: giữ Flutter.** v1 là Flutter, không phải Expo/React Native. Tầng core đã có test tốt.
  Viết lại UI trên cùng project (nhánh v2), bỏ code native recorder.
- Android trước; iOS để sau, giữ code trung lập nền tảng ở core.
- Nhóm push giữ 2 channel: `creator_live` (HIGH) và `recordings`.

---

## 3. Backend cần thêm (thiết kế + ước lượng, CHƯA code)

Ước lượng tính theo ngày công cho 1 dev, đã gồm test và migration.

### 3.1 Xác minh chủ kênh bằng mã trong bio (web + app) — **5–7 ngày**

**Hiện trạng:**

- Chỉ có `watches.owner_attested_at` (tự cam kết, không bắt buộc).
- Hàm lấy profile `core/tiktok_api.py:170-239` đã tải và parse JSON trang profile, nhưng **bỏ qua `signature` (bio)**, `id` và `secUid`.

**Dữ liệu (migration 0032):**

- Bảng `channel_verifications`:
  - `id`, `user_id`, `watch_id`, `username` (chuẩn hoá), `code` (`SS-XXXX`, bảng chữ Crockford base32 bỏ O/I/L, 4 ký tự), `status`, `attempts`;
  - `status` nhận một trong các giá trị: `pending` / `verified` / `expired` / `failed`;
  - `expires_at` (mặc định **30 phút**, runtime setting), `last_checked_at`, `verified_at`;
  - `tiktok_user_id` / `sec_uid` lấy được lúc xác minh.
- Cột mới trên `watches`:
  - `owner_verified_at`, `owner_verified_user_id` (id TikTok cố định, để chịu được đổi username);
  - `verification_method` (`bio_code` | `admin`).
- Thêm `verified_channels` vào entitlement và `owner_verified` vào `WatchResponse`.

**API:**

- `POST /v1/watches/{id}/verification`: tạo hoặc làm mới mã. Mỗi watch chỉ có 1 mã còn hạn. Giới hạn 5 lần/giờ.
- `POST /v1/watches/{id}/verification/check`: server tải profile và tìm mã trong bio (không phân biệt hoa thường, bỏ khoảng trắng).
  - Thành công: set `owner_verified_at`, trả `verified`, gợi ý "You can remove the code now".
  - Giới hạn 1 lần/10 giây, 20 lần/giờ.
  - Lỗi mạng hoặc TikTok WAF trả `retry_later`, không tính là thất bại.
- `GET /v1/watches/{id}/verification`: trạng thái, mã, hạn.
- Admin: `POST /v1/admin/watches/{id}/verify` (lý do bắt buộc, có audit), dùng cho đối tác hoặc trường hợp bio bị khoá.

**Chặn ghi khi chưa xác minh.** Thêm 1 hàm `ensure_watch_verified()` và gọi ở **mọi điểm tạo bản ghi**:

- `RecordingService.create_for_user` (`application/recordings/service.py:214`). Áp cho POST thủ công:
  - chỉ nhận nguồn `username`/`url` khớp một watch đã xác minh của chính user;
  - người dùng thường không được dùng nguồn `room_id`.
- `WatchScheduler._auto_record` (`application/watches/scheduler.py:262`): kênh chưa xác minh vẫn được theo dõi LIVE nhưng không ghi. Gửi thông báo "verify to record".
- `CloudSlotQueueService.queue_for_watch` và `promote_checked_room` (`application/recordings/cloud_slots.py:45, :254`). Hai chỗ này hiện bỏ qua `create_for_user`.
- `LocalRecordingService.start`: tắt hẳn route `/v1/local-recordings/*` ở v2 (§3.6).
- Admin retry giữ quyền override.

**Kiểm tra bio từ server:**

- Mở rộng `TikTokProfile` thêm `signature`, `user_id`, `sec_uid`.
- Đi qua proxy và retry, có cache ngắn 10 giây cho từng username.
- Đổi username sau khi xác minh: scheduler dùng `owner_verified_user_id` để so khớp. Nếu id khác thì huỷ xác minh và báo người dùng.

**Rủi ro:**

- TikTok hay trả trang WAF/đăng nhập, nên cần proxy và retry. Nếu vẫn lỗi thì cho admin xác minh tay.
- Về lâu dài, phương án chuẩn hơn là **TikTok Login Kit (OAuth)**. Cần duyệt ứng dụng developer của TikTok; đây là quyết định của chủ sản phẩm.

**Chuyển đổi kênh cũ:**

1. Ngày D: deploy. Kênh cũ có nhãn "Verify to keep recording" trên web và email thông báo. Vẫn ghi bình thường trong **14 ngày** ân hạn.
2. D+7: email nhắc lần 2 và thông báo trong app.
3. D+14: bật chặn. Kênh chưa xác minh tự chuyển `auto_record=off` (vẫn theo dõi). Bản ghi cũ giữ theo hạn lưu trữ.
4. Báo cáo admin: số kênh đã/chưa xác minh. Kênh của đối tác thì admin xác minh tay.

**Test:** unit (sinh mã, hết hạn, chuẩn hoá); API với fake profile lookup (có mã / không mã / WAF); chặn ở cả 4 điểm tạo bản ghi; đổi username; migration với dữ liệu cũ.

### 3.2 Google Play Billing (one-time Starter/Standard/Premium) — **3–4 ngày** (phần lớn đã có)

**Đã có:**

- `infrastructure/store/google_play.py`:
  - verify `purchases.products.get`, kiểm tra `purchaseState==0`, productId, orderId, quantity;
  - acknowledge và consume;
  - RTDN qua Pub/Sub OIDC.
- `POST /v1/billing/store-purchases`: idempotent theo `(provider, provider_reference)` và grant reference.
- Hoàn tiền: `voidedPurchaseNotification` thu hồi credit.
- Sản phẩm seed sẵn: `savestream.hours.50` / `.150` / `.400` (3.000 / 9.000 / 24.000 credit).
- Test trong `test_v2_b5_store_purchases.py`.

**Cần sửa / thêm:**

1. `/v1/public/pricing` đang hardcode `google_play=False` (`api/routes/public.py:52-74`). Đổi thành đọc runtime setting `payment_google_play_enabled`.
2. `store_product_ids` chỉ trả khi **cả** Apple và Google đều có ID (`api/serializers/billing.py:19-26`). Tách để Android vẫn nhận ID khi bỏ Apple.
3. Dùng **`purchaseToken` làm `provider_reference`** thay `orderId` (orderId có thể rỗng với test/promo). Migration mềm: giữ đọc orderId cũ.
4. Gắn user: app gửi `obfuscatedAccountId = sha256(user_id)` khi mua. Server so khớp để chống dùng token của người khác.
5. RTDN:
   - `testNotification` và `oneTimeProductNotification` phải trả **204** (hiện trả 422 nên Pub/Sub gửi lại mãi);
   - `oneTimeProductNotification(PURCHASED)` dùng để tự grant khi app chết giữa chừng.
6. Job định kỳ:
   - retry acknowledge/consume cho đơn `store_finalize_pending`. Google tự hoàn tiền sau 3 ngày nếu chưa acknowledge;
   - đối soát `voidedpurchases.list` hằng ngày.
7. `purchaseState==2` (pending, ví dụ trả tiền mặt) trả `pending` chứ không 422. Grant khi RTDN báo PURCHASED.
8. Thu hồi khi số dư không đủ (đã tiêu): ghi nợ âm và chặn ghi mới. **Cần chủ sản phẩm quyết** (§6).

**Test:** bổ sung cho các mục 1–7 với fake Play API; RTDN test notification; token của user khác; pending → purchased.

### 3.3 Rewarded ads AdMob + SSV (+5 phút cloud, tối đa 6/ngày) — **3–4 ngày**

**Đã có:**

- `POST /v1/rewards` tạo intent (`ssv_user_id`, `ssv_custom_data = reward_id`).
- Webhook `GET /v1/webhooks/admob-ssv` verify ECDSA bằng key của Google.
- Chống trùng `transaction_id`, gắn user, khoá tạm khi chữ ký sai liên tiếp.

Phần còn thiếu: hiện reward chỉ cộng **phút ghi trên máy** (10 phút, 8/ngày).

**Thay đổi:**

- Purpose mới `cloud_minutes`:
  - khi SSV hợp lệ, ghi ledger `reward` **+5 credit** (5 phút), idempotent theo `reward_id`;
  - `reward_minutes=5`, `reward_daily_cap=6` là runtime setting.
- Bỏ purpose `local_minutes` và `local_slot` ở v2. API cũ trả 410 cho client mới.
- Chống gian lận:
  - **chỉ tài khoản đã xác minh email**;
  - cap theo user **và theo thiết bị** (`device_id` lúc tạo intent);
  - intent hết hạn sau 1 giờ;
  - kiểm tra `ad_unit` nằm trong allowlist và `reward_amount` đúng cấu hình;
  - **gặp `key_id` lạ thì tải lại key ngay** (hiện cache 24 giờ);
  - không đổi trạng thái intent khi chữ ký sai (chỉ log và đếm theo IP);
  - giới hạn tốc độ tạo intent;
  - cảnh báo admin khi một thiết bị có trên 3 tài khoản.
- Thêm vào entitlement khối `ads`:
  - `rewarded_available`, `rewards_left_today`, `minutes_per_reward`, `resets_at`;
  - `show_banners`: `true` chỉ khi tài khoản **chưa từng mua** gói nào; mua bất kỳ gói nào thì `false` (`has_paid_purchase`, §4.4).
- **Mốc reset ngày:** hiện tính theo UTC, bản nháp ghi "resets at midnight". Cần chọn UTC hay múi giờ thiết bị (§6).

**Test:** chữ ký thật với key server giả (đã có khung test); cap 6/ngày theo user và thiết bị; replay transaction; key rotation; ad unit sai; tài khoản chưa xác minh email.

### 3.4 Xoá tài khoản trong app + trang web xoá tài khoản — **2–3 ngày**

**Đã có:**

- `DELETE /v1/me` (202): khoá tài khoản, thu hồi phiên và thiết bị.
- Job `anonymize_due_accounts`: xoá mềm bản ghi và file, ẩn danh email, giữ hồ sơ tài chính.
- App v1 đã có màn xoá.

**Thiếu:**

1. **Trang công khai `https://savestream.online/delete-account`**: URL bắt buộc trong Data safety.
   - Trang giải thích dữ liệu nào bị xoá hoặc giữ, thời hạn, và cách xoá trong app.
   - Người chưa đăng nhập nhập email, hệ thống gửi link xác nhận (one-time token, hết hạn 1 giờ). Bấm link thì gọi cùng luồng `request_account_deletion`.
   - Có Turnstile và rate limit giống `/report`.
2. Ẩn danh còn sót nhiều bảng, phải xử lý thêm:
   - `SocialIdentity`: nếu không xoá, người dùng đăng nhập Google lại sẽ bị kẹt `AUTH_SOCIAL_UNAVAILABLE`;
   - `RewardIntent`, `LocalRecordingSession`, `LocalDailyUsage`, `channel_verifications`;
   - watch `creator_*` và `owner_*`;
   - `PartnerApplication` (theo Privacy §10);
   - `AdminEmailLog` (xoá địa chỉ email).
3. Outbox `identity.account_deletion_requested` chưa có consumer: gửi email xác nhận "your account was deleted".
4. Thông báo cho Google Play: sau khi xoá, đơn hàng vẫn giữ để đối soát hoàn tiền (đã ghi trong Privacy "Retention").

**Test:** luồng web (email → link → xoá); ẩn danh đủ các bảng; tạo lại tài khoản bằng cùng Google sau khi xoá.

### 3.5 Push notification (FCM) — **1–2 ngày** (phần lớn đã có)

**Đã có:**

- FCM HTTP v1. Đăng ký thiết bị qua `PUT/DELETE /v1/me/devices/{id}`.
- 12 loại thông báo (creator_live, recording_started/ready/failed/missed, purchase_completed, credits_low, …), có công tắc theo loại và hai channel Android.

**Thêm:**

- Coi `INVALID_ARGUMENT` / `NOT_FOUND` là token chết.
- Một token chỉ thuộc một user: khi đăng ký thì gỡ token khỏi user khác.
- Loại mới: `channel_verification_needed` (ân hạn §3.1), `reward_credited` (tuỳ chọn).
- Bỏ copy tiếng Việt khỏi push nếu app chỉ tiếng Anh.
- Bật `SAVESTREAM_PUSH_PROVIDER=fcm` trên production với service account của project Firebase của app.

### 3.6 Dọn backend cho v2 — **1–2 ngày**

- **Tắt `/v1/local-recordings/*`.** Route này cấp URL luồng thô và header cho client. Bỏ setting `free_local_daily_minutes` khỏi entitlement của client mới.
- Đăng ký trên mobile phải gửi consent 18+/Terms/Privacy/AUP như web (sửa `auth.py:91`, `identity/service.py:471`). App v1 cũ vẫn chạy: chấp nhận thiếu consent cho `app_version < 3.0`, sau đó bắt buộc.
- `GET /v1/app/status`: đặt `min_supported_android` để buộc cập nhật khỏi v1 khi v2 phát hành.
- Apple: để tắt bằng cấu hình. Không xoá code (an toàn).

### 3.7 Tổng ước lượng backend

| Hạng mục | Ngày |
|---|---|
| 3.1 Xác minh kênh (+ chuyển đổi web) | 5–7 |
| 3.2 Google Play Billing | 3–4 |
| 3.3 Rewarded ads SSV | 3–4 |
| 3.4 Xoá tài khoản + trang web | 2–3 |
| 3.5 FCM | 1–2 |
| 3.6 Dọn backend | 1–2 |
| **Cộng** | **15–22 ngày** |

App Flutter v2:

- Xoá recorder và dọn code: 2–3 ngày.
- Tầng UI 8 màn + onboarding: 8–12 ngày, sau khi có artboard.
- Billing, ads, push, deep link: 3–4 ngày.
- Test và chuẩn bị nộp: 3–4 ngày.
- Cộng khoảng 16–23 ngày.

Thứ tự đề xuất: 3.6 và 3.1 trước (đổi luật chơi cho cả web), song song 3.4. Sau đó 3.2, 3.3, 3.5.
Mỗi hạng mục một PR, CI xanh, QA duyệt, deploy backend bằng drain.

---

## 4. Checklist nộp Google Play

### 4.1 Tài khoản và cấu hình

- [ ] Google Play Console (tài khoản tổ chức). Nếu là tài khoản cá nhân tạo sau 11/2023 thì phải
  **closed testing ≥ 12 tester trong 14 ngày** trước khi lên production.
- [ ] Package name. Nếu `com.savestream.app` đã từng phát hành bản có recorder thì cần quyết: cập nhật bản cũ hay app mới (§6).
- [ ] Play App Signing, upload key lưu an toàn (không commit keystore).
- [ ] Target API level mới nhất mà Play đang yêu cầu cho app mới (kiểm tra lại lúc nộp).
- [ ] Firebase project cho app: `google-services.json` đặt lúc build, không commit.

### 4.2 Data safety (khai báo trung thực)

> **Chủ sản phẩm tự điền các mục này trong Play Console** (App content › Data safety, và App content ›
> Ads). Bảng dưới là bản đối chiếu với code (`apps/mobile` nhánh credits + backend), không phải
> câu chữ của Play. Khi code đổi thì sửa bảng này trước khi cập nhật Play Console.

| Dữ liệu (nhóm Play) | Thu thập | Chia sẻ | Mục đích | Ghi chú |
|---|---|---|---|---|
| Email, tên hiển thị (Personal info) | Có | Không | Tài khoản | |
| User ID (Personal info) | Có | Không | Tài khoản, chống gian lận | Khi mua, app gửi Google `obfuscatedAccountId` = SHA-256 của user id (không phải email) |
| Lịch sử mua (Financial info › Purchase history) | Có | Không | Thanh toán | Google Play xử lý thanh toán; server nhận purchase token, order id, product id, trạng thái, và giá Google Play đã hiện cho người dùng (`price_amount_micros` + mã tiền tệ, chỉ để hiển thị trong Purchases). Không nhận số thẻ |
| Tương tác trong app (kênh, bản ghi) (App activity) | Có | Không | Chức năng app | |
| **Advertising ID** (Device or other IDs) | **Có** | **Có — Google AdMob** | **Quảng cáo; chống gian lận, bảo mật** | Do SDK Google Mobile Ads thu thập (rewarded + banner). Quyền `com.google.android.gms.permission.AD_ID` do SDK merge vào manifest (không `tools:node="remove"`). App không tự đọc hay gửi Advertising ID về server SaveStream |
| **Device or other IDs**: install id của app (`device_id`, chuỗi ngẫu nhiên 128 bit `dev_…` sinh khi cài, lưu trong secure storage) | Có | Không | Chống gian lận, bảo mật | Gửi kèm `POST /v1/rewards` khi tạo lượt xem quảng cáo thưởng: cap 6 lượt/ngày/thiết bị, cảnh báo một máy có hơn 3 tài khoản. Cũng là khoá đăng ký thiết bị cho push. Xoá cùng tài khoản |
| **Device or other IDs**: push token FCM | Có | Không (Google FCM là bên xử lý thay mặt chúng ta) | Chức năng app (thông báo) | Gửi qua `PUT /v1/me/devices/{id}` cùng nền tảng (android/ios), phiên bản app, ngôn ngữ. **Không gửi tên máy (hãng + model)**: trường `device_name` backend còn bắt buộc nên app gửi hằng số trung tính `Android`/`iOS` (backend sẽ cho phép bỏ trường này ở PR riêng). Xoá khi đăng xuất hoặc xoá tài khoản |
| Video bản ghi (của kênh đã xác minh) (Photos and videos) | Có | Không | Chức năng app | |
| Crash/analytics | Không (đã bỏ firebase-analytics) | — | — | |

Khai báo ngoài bảng:

- [ ] **Contains ads = Có** (App content › Ads, hiện trên Store listing). App có rewarded tự nguyện và
  một banner cuối Home cho người chưa từng mua (§4.4).
- [ ] Dữ liệu được mã hoá khi truyền: có (HTTPS).
- [ ] Người dùng yêu cầu xoá được: có, trong app và qua `https://savestream.online/delete-account` (§3.4).
- [x] `app-ads.txt` đã đăng tại `https://savestream.online/app-ads.txt` (PR #242).
- [x] SSV callback URL trong AdMob (`https://api.savestream.online/v1/webhooks/admob-ssv`): chủ sản phẩm đã xác nhận.
- [ ] Privacy Policy URL: `https://savestream.online/privacy`. Cần bổ sung mục mobile: FCM, AdMob, Play Billing,
  install id. **Câu chữ cần chủ sản phẩm duyệt** (bản nháp đang soạn, chưa merge).

### 4.3 Quyền

- [ ] Chỉ còn INTERNET, POST_NOTIFICATIONS, BILLING, quyền của FCM, và AD_ID (do SDK Google Mobile Ads merge; app có rewarded + banner).
- [ ] Không có foreground service nên không phải nộp form FGS.
- [ ] Hỏi POST_NOTIFICATIONS đúng ngữ cảnh (sau khi thêm kênh), không hỏi ngay khi mở app.

### 4.4 Quảng cáo

- [ ] **Dùng lại AdMob của v1** (cùng package `com.savestream.app`): App ID Android `ca-app-pub-2078852906622512~2464439785`, Rewarded `ca-app-pub-2078852906622512/5155016450`, Banner `ca-app-pub-2078852906622512/4061426634`. ID lấy từ build config của app (`--dart-define`) và env server `SAVESTREAM_ADMOB_REWARD_AD_UNITS`, không viết cứng trong code.
- [x] SSV callback URL trong AdMob là `https://api.savestream.online/v1/webhooks/admob-ssv` (AdMob → Ad unit Rewarded → Server-side verification). **Chủ sản phẩm đã xác nhận.**
- [ ] Số thưởng đặt trong AdMob không cần đổi: server luôn cộng 5 phút cloud cho mỗi lượt SSV hợp lệ từ ad unit trong allowlist.
- [ ] Rewarded: người dùng **tự bấm** "Watch ad · +5 min". Không quảng cáo bất ngờ, không xen ngang player.
- [ ] **Banner (quyết định cuối của chủ sản phẩm):** một banner nhỏ, chỉ cho tài khoản **chưa từng mua** (`entitlement.ads.show_banners`), đặt **ở cuối Home và chỉ ở đó**. Không bao giờ có ở màn player, mua/thanh toán, xác minh kênh (và không ở Channels, Library). Không che nút. Mua bất kỳ gói nào thì tắt banner.
- [ ] **Personalized ads (quyết định cuối của chủ sản phẩm), theo Google UMP:**
  - **EEA/UK/Thuỵ Sĩ:** form đồng ý UMP hiện **trước khi tải bất kỳ quảng cáo nào** (`ensureConsent()` chạy trước mọi lần tải rewarded/banner). Nếu người dùng không đồng ý, quảng cáo không cá nhân hoá hoặc theo đúng lựa chọn trong UMP: app để SDK/UMP quyết, không thêm cờ chặt hơn.
  - **Các bang Mỹ có luật quyền riêng tư:** app hỗ trợ thông điệp US states của UMP: khi `ConsentInformation.privacyOptionsRequirementStatus == required`, nút "Review privacy choices" (Settings › Ad privacy choices) gọi `ConsentForm.showPrivacyOptionsForm` để người dùng từ chối bán/chia sẻ dữ liệu.
  - **Mọi nơi khác:** personalized ads **BẬT mặc định**.
  - Người dùng luôn tắt được công tắc "Personalized ads" (Settings › Ad privacy choices). Công tắc lưu trên máy, áp cho cả rewarded và banner; tắt thì mọi request là non-personalized (`npa=1`).
- [ ] **Chủ sản phẩm cấu hình trong AdMob console:** Privacy & messaging › **European regulations** (GDPR, đã có) và Privacy & messaging › **US state regulations**: tạo và publish thông điệp US states cho app Android `com.savestream.app`. App không cần đổi code khi bật/tắt thông điệp này.
- [ ] Đối tượng **18+**, không nhắm trẻ em (Families policy không áp dụng). Content rating qua IARC.
- [ ] Khai báo "Contains ads" = **Có** trong Store listing / App content (§4.2).
- [x] `app-ads.txt` đã đăng tại `https://savestream.online/app-ads.txt` (PR #242).

### 4.5 Tài khoản test cho reviewer

- [ ] Tài khoản `review@savestream.online` (mật khẩu ghi trong Play Console › App access, không ghi trong repo).
- [ ] Một kênh TikTok **của chính SaveStream** đã xác minh. Vài bản ghi mẫu là LIVE do chính chúng ta phát. Không dùng nội dung của người khác.
- [ ] Đủ credit để thử. Hướng dẫn từng bước trong App access: thêm kênh, xác minh, xem bản ghi, mua thử bằng license tester.
- [ ] Reviewer dùng **đúng bản production**, không có chế độ riêng cho review.

### 4.6 Store listing trung thực

- [ ] Tên: "SaveStream: LIVE Recorder" hoặc tương tự, **không có chữ TikTok trong tên và icon**.
  Trong mô tả được nói đúng sự thật: "Record your own TikTok LIVEs in the cloud". Kèm câu
  "SaveStream is not affiliated with or endorsed by TikTok."
- [ ] Mô tả đúng tính năng thật: chỉ kênh của bạn, phải xác minh, ghi trên cloud, credit theo phút, gói one-time.
- [ ] Ảnh chụp từ app thật với dữ liệu demo của chính chúng ta.
- [ ] **Không** dùng mẹo né kiểm duyệt:
  - không viết tắt "TT";
  - không đổi mô tả hay tính năng sau khi được duyệt;
  - không ẩn tính năng lúc review;
  - không remote flag bật tính năng sau.
- [ ] Payments: mọi giao dịch số trong app dùng Google Play Billing. Không link tới checkout web trong app.

### 4.7 Trước khi bấm nộp

- [ ] Merged manifest của AAB đúng danh sách quyền ở §4.3.
- [ ] `flutter analyze` và test xanh. Chạy thử internal track trên 2–3 máy thật.
- [ ] Pre-launch report của Play không có lỗi nghiêm trọng.
- [ ] Backend production: verification bật, local recordings tắt, Play Billing bật, SSV bật, FCM bật.

---

## 5. Ghi chú thiết kế (đối chiếu bản nháp 8 màn)

- Màn 3 (Add channel + verify) khớp §3.1: mã `SS-XXXX`, "Check my bio", nút Add bị khoá đến khi xác minh xong.
  Cần thêm các trạng thái: hết hạn mã, không thấy mã, TikTok tạm lỗi (retry), đã xác minh.
- Màn 7 (Credits):
  - 50/150/400 giờ khớp catalog hiện có (3.000/9.000/24.000 credit), nhưng phải hiển thị từ API, giá lấy từ Play (`[PRICE]`);
  - "time never expires" khớp chính sách hiện tại (credit không hết hạn). Cần chủ sản phẩm xác nhận câu này;
  - "resets at midnight": xem câu hỏi mốc reset (§6).
- Tải về máy và chia sẻ: chấp nhận được khi chỉ còn kênh đã xác minh. Đề xuất giữ "Download" nhưng bỏ nút "Share" ở bản đầu cho gọn.

---

## 6. Câu hỏi cần chủ sản phẩm quyết

1. **Google Play Console**: tài khoản tổ chức hay cá nhân, ai là chủ? Nếu cá nhân và mới thì cần 12 tester × 14 ngày closed test.
2. **Package name**: giữ `com.savestream.app` không? Bản v1 (có recorder) đã từng phát hành lên Play chưa, kể cả internal/closed?
3. ~~**AdMob**: dùng lại app ID hay tạo mới? Có banner cho người chưa mua không?~~ **Đã quyết:** dùng lại AdMob v1 (`ca-app-pub-2078852906622512~2464439785`). Rewarded tự nguyện + **một banner** chỉ cho người chưa từng mua (`entitlement.ads.show_banners`), chỉ ở cuối Home, không bao giờ ở player, mua/thanh toán, xác minh (§4.4). **Đã quyết (personalized ads):** BẬT mặc định ngoài EEA/UK/Thuỵ Sĩ; ở EEA/UK/Thuỵ Sĩ hỏi đồng ý bằng UMP trước khi tải quảng cáo; hỗ trợ thông báo US states của UMP (chủ sản phẩm bật trong AdMob › Privacy & messaging › US state regulations); người dùng tắt được trong Settings › Ad privacy choices (§4.4).
4. **Rewarded**: +5 phút, 6 lần/ngày. Reset theo **UTC** hay giờ địa phương? Có giới hạn tháng không?
5. **Xác minh kênh**: đồng ý mã trong bio làm phương án chính và TikTok Login Kit (OAuth) là hướng dài hạn? Ân hạn 14 ngày cho kênh cũ trên web có ổn không? Đối tác thì admin xác minh tay?
6. **Hoàn tiền khi credit đã tiêu**: cho số dư âm và chặn ghi, hay chỉ thu hồi phần còn lại?
7. **Giá Play**: giữ $9.99 / $24.99 / $59.99 như web, hay giá riêng (phí Play 15%)?
8. **Tên trên store và câu "not affiliated"**: chọn tên app (không có chữ TikTok).
9. **Download/Share** trên app: giữ Download, bỏ Share ở bản đầu?
10. **iOS**: để sau hoàn toàn? Nếu có, sẽ cần Sign in with Apple và StoreKit (code backend đã có, đang tắt).
11. **Privacy Policy mobile**: bổ sung FCM, AdMob, Play Billing. Tôi sẽ soạn câu chữ để duyệt trước khi merge, giống lần PostHog.
12. **Firebase**: dùng project Firebase hiện tại (đang dùng cho Google sign-in web) cho app Android luôn không?
