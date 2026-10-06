# Track A — Giao diện app (Flutter, dữ liệu giả trước)

Đọc [README.md](README.md), [DECISIONS.md](DECISIONS.md) và [API_CONTRACT.md](API_CONTRACT.md) trước.

**Mục tiêu:** dựng toàn bộ màn hình V2 trong `apps/mobile` theo gói thiết kế, chạy được với repository giả (mock). Track C sẽ thay mock bằng API thật và phần native; Track A không gọi mạng, không thêm plugin.

**Phạm vi file:** xem bảng quyền sở hữu trong README. Tóm tắt: `lib/features/**/presentation`, `lib/features/**/domain`, `mock_*` repository, `lib/core/widgets`, `lib/app/router`, `lib/app/theme`, `lib/l10n/*.arb`, test có tiền tố `v2a_`. **Không sửa `pubspec.yaml`, `bootstrap.dart`, `android/`, `ios/`.**

## Tiến độ

- [x] A0 — Nền móng: model, interface, mock, widget dùng chung — **đã merge PR #77 vào `main`**
- [x] A1 — Auth và Onboarding — **đã merge PR #81 vào `main`**
- [x] A2 — Home và Theo dõi — **đã merge PR #87 vào `main`**
- [x] A3 — Luồng ghi (Recording) — **đã merge PR #94 vào `main`**
- [x] A4 — Bản ghi và Trình phát — **đã merge PR #126 vào `main`**
- [x] A5 — Gói, sử dụng và mua giờ — **đã merge PR #135 vào `main`**
- [x] A6 — Cài đặt, Thông báo, trạng thái toàn cục — **đã merge PR #144 vào `main`**
- [x] A7 — Luồng biên, trợ năng, dọn code cũ — **đã merge PR #157 vào `main`**

### Trạng thái triển khai hiện tại — 2026-10-06

| Phase | Branch / PR | Trạng thái | Kiểm tra |
|---|---|---|---|
| A0 | `track-a/a0-foundation` / #77 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `mobile-backend-e2e` ✅ |
| A1 | `track-a/a1-auth-onboarding` / #81 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `mobile-backend-e2e` ✅ |
| A2 | `track-a/a2-home-watching` / #87 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `android-emulator-smoke` ✅ · `mobile-backend-e2e` ✅ |
| A3 | `track-a/a3-recording-flow` / #94 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `mobile-backend-e2e` ✅ |
| A4 | `track-a/a4-recordings-player` / #126 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `mobile-backend-e2e` ✅ |
| A5 | `track-a/a5-plans-usage-hours` / #135 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `android-emulator-smoke` ✅ · `mobile-backend-e2e` ✅ |
| A6 | `track-a/a6-settings-notifications-global` / #144 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `android-emulator-smoke` ✅ · `mobile-backend-e2e` ✅ |
| A7 | `track-a/a7-edge-accessibility-cleanup` / #157 | ✅ Hoàn tất, đã merge vào `main` | `flutter-checks` ✅ · `ios-release-compile` ✅ · `android-emulator-smoke` ✅ · `mobile-backend-e2e` ✅ |

**Quy tắc cập nhật tracking:** chỉ đánh dấu `[x]` khi phase đã merge vào `main`. Phase đang mở PR vẫn giữ `[ ]` và ghi trạng thái ở bảng trên.

## Kiểm tra (chạy trong `apps/mobile` trước khi mở PR)

```bash
flutter pub get --enforce-lockfile
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib/app lib/core lib/features lib/l10n/l10n.dart test
flutter analyze --fatal-infos
flutter test
bash tool/phase17_release_audit.sh
```

CI phải xanh: `flutter-checks`, `ios-release-compile`, `mobile-backend-e2e`.

## Quy tắc chung cho mọi phase của Track A

1. **Mỗi màn một file** trong `lib/features/<khu>/presentation/`, dòng comment đầu ghi ID màn theo thiết kế (ví dụ `/// W10 — Creator detail · LIVE`).
2. **Chữ trên màn:** lấy từ `docs/v2/design/docs/SCREENS.md` (tiếng Việt) và tự dịch sang tiếng Anh. Thêm cả hai vào `app_en.arb` và `app_vi.arb`. Không viết cứng chữ trong widget.
3. **Sửa chữ theo `DECISIONS.md`:**
   - Không có thuê bao: bỏ mọi chỗ "/tháng", "/năm", "gia hạn", "kỳ", "30 giờ mỗi kỳ".
   - "Pro" là tài khoản có giờ đã mua. Lời mời nâng cấp là "Mua giờ cloud".
   - Thời hạn lưu cloud: 30 ngày (đã mua), 7 ngày (chưa mua). Thay mọi chỗ "14 ngày".
   - Giờ cloud hiển thị dạng "133 giờ 20 phút", đổi từ phút. Không hiện chữ "credit" trong app.
   - Tên miền: `savestream.online`.
   - Bản ghi cloud lỗi: "không tính phút", không phải "chỉ tính phần đã lưu".
4. **Trạng thái của mỗi màn:** dựng đủ các biến thể có trong `docs/v2/design/docs/BACKLOG.md` cho màn đó (loading, empty, error, offline, limit). Loading dùng skeleton giữ đúng bố cục, không dùng vòng xoay toàn màn.
5. **Quảng cáo:** chỉ đặt chỗ bằng widget `SsBannerAdSlot` (tạo ở A0). Chỉ hiện khi `plan == free`, không bao giờ trên màn đang ghi, paywall, màn mua, trình phát, và trước khi người dùng thêm kênh đầu tiên.
6. **Local/Cloud luôn có icon kèm chữ** (`SsLocationChip`).
7. **Trợ năng:** vùng chạm tối thiểu 44, chữ co giãn tới 200% không tràn, có `Semantics` cho nhãn trạng thái, đồng hồ và công tắc.
8. **Test:** mỗi phase thêm widget test cho từng màn chính (hiển thị đúng với mock `success`, `empty`, `error`) và test cho controller mới. Không xoá test cũ trừ khi màn đó bị thay; khi thay thì viết lại test tương đương.
9. **Điều hướng:** thêm route vào `lib/app/router/app_routes.dart` và `app_router.dart`. Giữ `StatefulShellRoute` 4 tab: Home, Theo dõi, Bản ghi, Cài đặt.
10. **Model đóng băng sau A0:** từ A1 trở đi chỉ được thêm trường hoặc phương thức có giá trị mặc định vào model và interface; không đổi tên, không xoá. Khi thêm, sửa tối thiểu các file ánh xạ trong `data/remote/` và repository để biên dịch được, và liệt kê trong PR (xem "Ngoại lệ được phép" trong README).

---

## A0 — Nền móng

**Trạng thái:** ✅ **HOÀN TẤT** — PR #77 đã merge vào `main` ngày 2026-10-04. Branch triển khai: `track-a/a0-foundation`.

**Kết quả đã chốt:** model/interface/mock V2, native contracts + fake providers, `SaveStreamApp.extraOverrides`, widget dùng chung + `/dev/components`, formatter, ARB native EN/VI và test A0. CI trước merge đã xanh đủ `flutter-checks`, `ios-release-compile`, `mobile-backend-e2e`.

**Phụ thuộc:** không. **Chặn:** C0 và mọi phase A sau.

Việc cần làm:

1. **Enum và model** trong `lib/features/<khu>/domain/models/` (tên khớp `API_CONTRACT.md`):
   - `Plan { free, pro }`, `Engine { local, cloud }`.
   - `Entitlement` (plan, hasPurchased, cloudMinutesAvailable, giới hạn, khối `local`).
   - Mở rộng trạng thái bản ghi: thêm `waitingForCloudSlot`, `missedNoCloudSlot`, và các trạng thái của bản ghi trên máy: `starting`, `recording`, `reconnecting`, `finalizing`, `completed`, `partial`, `recovered`, `failed`.
   - `AutoRecordState { off, active, pausedNoCloudMinutes, waitingForCloudSlot }`, thêm `notifyOnLive` và `autoRecordState` vào model kênh.
   - `LocalRecordingSession`, `LocalRecordingSummary`, `RecordingEndReason`, `Reward` và `RewardStatus`, `StorePackage`, `StorePurchaseResult`, `AppStatus` (bắt buộc cập nhật, bảo trì), `DeviceRegistration`.
2. **Interface repository** trong `domain/repositories/`, mỗi cái có bản `Mock…` trong `data/repositories/` kế thừa `MockRepositoryBase` (hỗ trợ đủ 5 `MockScenario`):
   - `EntitlementRepository` (`getEntitlement()`), thêm `MockScenario` phụ để đổi giữa Free, Free hết phút, Pro, Pro hết giờ.
   - `LocalRecordingRepository` (start, extend, finish, list, delete).
   - `RewardRepository` (create, getStatus).
   - `StoreRepository` (listPackages, submitPurchase).
   - `AppStatusRepository`, `DeviceRepository`.
3. **Interface cho phần native** trong `lib/platform/contracts/` (Track A tạo file interface, Track C viết bản thật ở `lib/platform/`):
   - `LocalRecorder`: `Stream<LocalRecorderState> watch()`, `start(session)`, `stop()`, `recover()`.
   - `PurchaseService`: `loadProducts(ids)`, `buy(productId)`, `restore()`, stream trạng thái mua.
   - `AdsService`: `showRewarded(reward)`, `bannerFor(placement)`, `consentState`.
   - `PushService`: `permissionStatus`, `requestPermission()`, `tokenStream`, `openedMessageStream`.
   - `ConnectivityService`: `Stream<bool> online`.
   - `DeviceInfoService`: `deviceId`, `deviceName`, `freeStorageBytes`, `platform`.
   - Mỗi interface có bản `Fake…` trong `lib/platform/fakes/` để giao diện chạy được và test được. Provider mặc định trả bản fake.
4. **Điểm nối cho Track C:** thêm tham số `List<Override> extraOverrides` vào `SaveStreamApp` (file `lib/app/savestream_app.dart`), nối vào cuối danh sách `overrides` của `ProviderScope`. Sau phase này không ai sửa file đó nữa; Track C chỉ truyền override từ `bootstrap.dart`.
5. **Widget dùng chung** trong `lib/core/widgets/`, dựng theo thiết kế (`docs/v2/design/design/SaveStream V2 Phase 1 Components.dc.html`): `SsLocationChip`, `SsPlanBadge`, `SsLiveBadge`, `SsQuotaCard` (biến thể Free, Free hết phút, Pro), `SsCreatorTile`, `SsRecordingTile`, `SsActiveRecordingCard`, `SsRecordingBar` (thanh nổi trên mọi tab khi đang ghi), `SsInlineAlert`, `SsFilterChips`, `SsBannerAdSlot`, `SsBottomSheet`, `SsToast`, `SsChecklist` (danh sách bước, dùng cho finalizing/processing). Thêm tất cả vào màn `/dev/components`.
6. **Tiện ích định dạng:** phút sang "X giờ Y phút", đếm ngược "Reset sau X giờ Y phút", dung lượng file, thời lượng `HH:MM:SS`.
7. **Chuỗi cho phần native** (tạo sẵn trong ARB để Track C dùng, không được đổi tên key sau này):
   `nativeRecordingNotificationTitle`, `nativeRecordingNotificationBody`, `nativeRecordingNotificationStop`, `nativeRecordingChannelName`, `nativeKeepAppOpenReminderTitle`, `nativeKeepAppOpenReminderBody`, `nativePushChannelLiveName`, `nativePushChannelRecordingName`.

Định nghĩa xong: mọi kiểm tra qua; màn `/dev/components` hiển thị đủ widget mới ở cả giao diện sáng và tối; có test cho từng mock repository và từng widget mới.

---

## A1 — Auth và Onboarding

**Trạng thái:** ✅ **HOÀN TẤT** — PR #81 đã merge vào `main` ngày 2026-10-04.

**Đã triển khai trong PR #81:**
- A01 splash theo V2; A03/A03-error, A04, A05, A05b, A06 và A06-verify đã dựng lại nhưng giữ nguyên auth controller/repository.
- Cờ hoàn tất phần giới thiệu được lưu bằng `AppSettingsStore`; router phân biệt Welcome, auth và first-run intro.
- A07 → A09 và nhánh nền tảng A10 Android / A11 iOS đã có; A09 gọi `PushService.requestPermission()`.
- A12 dùng lại `WatchController` để thêm creator đầu tiên, không có checkbox xác nhận quyền ghi; A13 hoàn tất intro rồi vào Home hoặc thêm creator khác.
- Đã thêm EN/VI localization và test A1 cho persistence, auth/onboarding first-run và nhánh iOS.
- Đã sửa verify deep-link để token mới vẫn được xử lý khi route giữ nguyên `/auth/verify` nhưng query thay đổi.

**Kiểm tra cuối:** `flutter gen-l10n`, formatter, analyzer, toàn bộ `flutter test`, Android production AAB + Phase 17 release audit đều xanh trong `flutter-checks`; `ios-release-compile` xanh; `mobile-backend-e2e` xanh với backend thật. PR #81 đủ điều kiện kỹ thuật để merge.

**Phụ thuộc:** A0. Màn A02 (Welcome) đã có sẵn ở `lib/features/onboarding/presentation/welcome_screen.dart`.

Màn: A01, A03, A03-error, A04, A05, A05b, A06, A06-verify, A07, A08, A09, A10, A11, A12, A13.

Việc cần làm:

1. Dựng lại bố cục các màn auth đang có (`sign_in`, `register`, `verify_email`, `forgot_password`, `reset_password`) theo thiết kế. **Giữ nguyên controller và repository**; chỉ đổi phần hiển thị.
2. **Không làm nút Google/Apple** (đợt sau). Bỏ dòng "hoặc dùng email".
3. A04: trường Họ tên, Email, Mật khẩu; quy tắc mật khẩu hiện trực tiếp và đổi sang trạng thái đạt khi đủ 8 ký tự.
4. A06 và A06-verify: nút "Mở ứng dụng email" gọi qua `url_launcher` (đã có trong dự án).
5. Luồng sau khi xác minh email lần đầu: A07 → A08 → A09 → (Android: A10, iOS: A11) → A12 → A13 → Home. Lưu cờ "đã xem giới thiệu" qua `AppSettingsStore`.
6. A09: nút "Bật thông báo" gọi `PushService.requestPermission()` (bản fake ở A0).
7. A10 (Android): giải thích thông báo "đang ghi" và tối ưu pin. A11 (iOS): giải thích phải giữ app mở khi ghi. Chọn theo `DeviceInfoService.platform`.
8. A12, A13: thêm kênh đầu tiên, dùng lại logic thêm kênh hiện có. Theo thiết kế, **không có ô tick** xác nhận quyền ghi; thay bằng một dòng nhắc trách nhiệm.

Định nghĩa xong: test luồng đầy đủ "mở app lần đầu → Welcome → đăng ký → xác minh → 3 bước giới thiệu → thêm kênh → Home". **Đã đạt trên PR #81.**

---

## A2 — Home và Theo dõi

**Trạng thái:** ✅ **HOÀN TẤT** — PR #87 đã merge vào `main` ngày 2026-10-04. Merge commit: `d865d9381d9c3a9c2f8cb885a2bfc5954c60626a`.

**Kết quả đã chốt:** Home/Watching V2 theo `DECISIONS.md`; Free 3 creator / Pro 20 creator; tài khoản Free cũ >3 giữ nguyên nhưng bị chặn thêm; công tắc báo khi LIVE theo từng creator; hàng chờ slot cloud + trạng thái Bỏ lỡ; W04–W15 và N04b–N04d; hiển thị giờ/phút, không dùng credit; EN mặc định + VI đầy đủ. CI trước merge xanh `flutter-checks`, `ios-release-compile`, `android-emulator-smoke`, `mobile-backend-e2e`.

**Phụ thuộc:** A1.

Màn: H01, H01-loading, H01-offline, H01-limit, H02, H03, H06, W01, W01-empty, W01-limit, W01-error, W03, W04–W08, W08-unavailable, W09, W10, W10-waiting, W11, W12, W13, W14, W15, N04b, N04c, N04d.

Việc cần làm:

1. **Home** đọc `Entitlement` để chọn biến thể:
   - Free: `SsQuotaCard` phút Free hôm nay, danh sách kênh đang LIVE với nút "Record ngay", thẻ mời mua giờ cloud, `SsBannerAdSlot` cuối trang.
   - Pro: thẻ bản ghi cloud đang chạy, thẻ giờ cloud còn lại (thay cho "12,6 / 30 h": hiện "Còn X giờ Y phút"), số slot đang dùng `n/3`, số kênh `n/20`. Không quảng cáo.
   - Trước khi có kênh đầu tiên: không thẻ mời mua, không quảng cáo.
2. **Theo dõi (Watch List):** bộ lọc Tất cả / LIVE / Offline / Paused, thanh sức chứa `n/3` hoặc `n/20`, công tắc "Thông báo khi LIVE" theo từng kênh, dòng "Auto-record trên cloud" (Free: khoá, mở màn mua giờ; Pro: công tắc).
3. **Đủ giới hạn:** nút thêm vẫn bấm được, mở sheet W13 dẫn tới màn mua giờ. Không ẩn, không vô hiệu nút.
4. **Thêm kênh** W04–W08: các trạng thái trống, đang kiểm tra, tìm thấy, không tìm thấy, riêng tư/không hỗ trợ, không xác định.
5. **Chi tiết kênh** W09–W11, W10-waiting (đang chờ slot cloud, hiện vị trí trong hàng chờ), W12 (xác nhận xoá), W15 (cài đặt tự động ghi của Pro, sửa chữ theo `DECISIONS.md`).
6. **Màn mở từ push** N04b–N04d: đang kiểm tra, còn LIVE (nút Record ngay), đã kết thúc.
7. Đổi tên tab "Channels" thành "Watching" (EN) / "Theo dõi" (VI) trong ARB.

---

## A3 — Luồng ghi

**Phụ thuộc:** A2.

Màn: Q06, R01-android, R01-ios, R02-android, R02-ios, R03, R03-slow, R04, R05, R06–R12, R08-pending, R08-invalid, R08-locked, R13–R16, R17, R18, R19, R20, R21, R22, R23, R24-android, R24-ios, R25-android, R25-ios, R26, R27, R28, H04, H05, H07, H08, H09, AN01–AN03, IO01–IO03.

Việc cần làm:

1. **Ghi trên máy (Free):** controller điều phối `LocalRecordingRepository` (xin phút, lấy địa chỉ luồng) và `LocalRecorder` (ghi file). Với bản fake, đồng hồ và dung lượng tăng giả lập.
2. Sheet bắt đầu ghi R01 chỉ hiện lần đầu hoặc khi cần xác nhận; các lần sau một chạm là ghi.
3. Màn đang ghi R02 và các trạng thái: đang kết nối, kết nối chậm (sau khoảng 8 giây), mất kết nối, cảnh báo còn 60 giây.
4. **Quảng cáo thưởng** R06–R12: tạo phần thưởng qua `RewardRepository`, hiện quảng cáo qua `AdsService`, hỏi trạng thái mỗi 2 giây; sau khoảng 15 giây chưa có kết quả thì hiện "xác nhận chậm". Giới hạn: 4 lần gia hạn một phiên, 8 phần thưởng một ngày.
5. **Ô ghi thứ 2** R13–R16: mở bằng 2 phần thưởng, có giờ hết hạn. Hết hạn không dừng phiên đang chạy, chỉ chặn phiên thứ 2 mới.
6. Bộ nhớ sắp đầy và gần hết (R17, R18), xác nhận dừng (R19), đang hoàn tất dạng danh sách bước không có phần trăm (R20), hoàn tất (R21).
7. **Khôi phục sau gián đoạn** R22–R25, khác nhau giữa Android và iOS.
8. **Pro ghi thủ công:** khi `entitlement.local.enabled`, bấm "Record ngay" mở sheet Q06 để chọn ghi trên máy (mặc định, không tốn giờ) hoặc trên cloud (ghi rõ sẽ trừ giờ). Khi `local.unlimited`, màn đang ghi trên máy không hiện phút còn lại, cảnh báo 60 giây hay lời mời xem quảng cáo. Khi `local.enabled = false`, bỏ qua sheet và ghi cloud luôn. Luôn đọc hai trường này từ entitlement, không tự suy ra từ `plan`.
9. **Bản ghi cloud (Pro):** R26 đang ghi, R27 đang xử lý, R28 lỗi. Dùng `RecordingRepository` hiện có. Không có nút xem trực tiếp khi đang ghi.
10. `SsRecordingBar` hiện trên mọi tab khi có phiên đang chạy; ẩn trên màn chi tiết đang ghi. Có 2 phiên thì chạm vào mở sheet chọn.
11. Các biến thể Home khi đang ghi: H04, H05, H07, H08, H09.
12. Màn hướng dẫn theo nền tảng: AN01–AN03 (Android), IO01–IO03 (iOS).
13. Không bao giờ hiện quảng cáo banner trên các màn của phase này.

---

## A4 — Bản ghi và Trình phát

**Phụ thuộc:** A3.

Màn: L01, L01-empty, L01-crossdevice, L01-missed, L02, L03, L04, L05, L06, L07, L07-expiring, L07-downloading, L07-downloaded, L08, L08-landscape, L09, L10, L11, L12, L13-local, L13-cloud, L13-both, L14, L14-cloud, L14-native.

Việc cần làm:

1. Danh sách gộp bản ghi cloud (`RecordingRepository`) và bản ghi trên máy (`LocalRecordingRepository` cộng chỉ mục file từ `LocalRecorder`), nhóm theo ngày, lọc theo nơi lưu và trạng thái, tìm theo tên kênh.
2. Bản ghi trên máy của thiết bị khác: chỉ đọc, hiện tên thiết bị nguồn và "Không có trên máy này"; không Phát, Chia sẻ, Xoá.
3. Chi tiết bản ghi trên máy L06; chi tiết cloud L07 với "Lưu đến ngày X" lấy từ `expires_at`; cảnh báo từ 3 ngày trước khi hết hạn; tải về máy có tiến độ theo byte.
4. **Trình phát** L08: dựng phần điều khiển (phát/tạm dừng, tua, toàn màn hình, xoay ngang) trên một widget `SsVideoSurface` nhận controller trừu tượng. Track C nối `video_player` thật vào. Không có quảng cáo trên trình phát.
5. Xoá theo ngữ cảnh L13: nút ghi rõ thứ bị xoá (bản trên máy, bản cloud, hoặc cả hai).
6. Chia sẻ L14: gọi qua interface `ShareService` (thêm vào `lib/platform/contracts/` cùng bản fake). Không có link công khai.
7. File trên máy bị mất hoặc di chuyển (L09), bản cloud đã hết hạn (L10), bản ghi một phần có dòng thời gian thiếu đoạn (L12), "Bỏ lỡ vì không có slot cloud" (L01-missed).

---

## A5 — Gói, sử dụng và mua giờ

**Phụ thuộc:** A4.

Màn (đã điều chỉnh theo `DECISIONS.md`): M01, M02, màn mua giờ (thay M03 và M10), M04 (5 ngữ cảnh), M05, M06, M07, M08, M09.

Việc cần làm:

1. **Gói và sử dụng** M01 (Free): phút Free hôm nay, phần thưởng đã dùng `n/8`, số kênh `n/3`, thẻ "Mua giờ cloud". M02 (Pro): giờ cloud còn lại, slot `n/3`, số kênh `n/20`, lưu cloud 30 ngày, nút "Mua thêm giờ", "Khôi phục giao dịch".
2. **Màn mua giờ:** ba gói 50 / 150 / 400 giờ lấy từ `StoreRepository`, **giá hiển thị lấy từ `PurchaseService.loadProducts`** (giá của store theo vùng), không viết cứng. Ghi rõ: mua một lần, không hết hạn, mở tự động ghi và 20 kênh, bỏ quảng cáo.
3. **5 ngữ cảnh mở màn mua** (M04): tự động ghi, danh sách kênh đầy, iOS chạy nền, hết phút Free, bỏ quảng cáo. Mỗi ngữ cảnh đổi tiêu đề và câu phụ, phần còn lại giống nhau.
4. Trạng thái mua: đang xử lý, thành công, người dùng huỷ (không báo lỗi), thất bại (có thử lại), đang chờ (chưa cấp Pro). Chỉ coi là thành công khi `StoreRepository.submitPurchase` trả `credited`.
5. Khôi phục giao dịch M09 với 4 trạng thái.
6. **Xoá** màn Credits, Billing, Billing Return và luồng checkout ngoài của bản cũ, cùng route, provider, mock, chuỗi ARB và test của chúng. Nói rõ trong PR những gì đã xoá.
7. Báo Track C cập nhật `tool/phase17_release_audit.sh` (script đang kiểm tra vài chuỗi của Billing cũ); không tự sửa file đó. Nếu script làm CI đỏ, giữ lại các key ARB mà script kiểm tra cho tới khi Track C sửa xong.

Không dựng: M11, M12, M13, M14 (thuê bao).

---

## A6 — Cài đặt, Thông báo, trạng thái toàn cục

**Phụ thuộc:** A5.

Màn: S01, S02, S03, S04, S05, S06, S07, S08, S09, S11, S12, S13, S14, S15, S16, S17, S18, N01, N02, N03, N05, G01–G07.

Việc cần làm:

1. Cài đặt theo Free và Pro; hàng "Record nền" chỉ có trên Android, iOS thay bằng "Giữ app mở khi record".
2. Bộ nhớ thiết bị (S03): chỉ áp dụng bản ghi trên máy, đọc từ `DeviceInfoService` và chỉ mục file.
3. Thông báo theo loại (S05), khớp các trường trong `API_CONTRACT.md` mục 7.
4. Bảo mật và tài khoản (S08): email, **đặt lại mật khẩu qua email** (không làm S10 đổi mật khẩu trong app), thiết bị đã đăng nhập (S09), đăng xuất, xoá tài khoản.
5. Đăng xuất khi đang ghi trên máy (S16): bắt buộc dừng và lưu xong mới đăng xuất. Bản ghi cloud không dừng.
6. Xoá tài khoản 2 bước (S17, S18); bỏ phần cảnh báo thuê bao của thiết kế, thay bằng cảnh báo mất giờ cloud đã mua.
7. Hộp thông báo N01, N02; xin quyền N03; quyền bị tắt N05. Chạm vào mục thông báo mở đúng màn liên quan.
8. **Toàn cục:** banner offline G01 (từ `ConnectivityService`), skeleton G02, lỗi tải G03, bắt buộc cập nhật G04 và bảo trì G06 (từ `AppStatusRepository`), phiên hết hạn khi đang ghi trên máy G05 (không chuyển màn, chỉ phủ lớp đăng nhập lại, không mất dữ liệu), toast G07.
9. Offline: hiện dữ liệu đã lưu kèm giờ cập nhật; hành động cần mạng bị vô hiệu kèm lý do, không ẩn.

---

## A7 — Luồng biên, trợ năng, dọn code cũ

**Phụ thuộc:** A6.

Màn: Q01, Q02, Q03, Q04, Q05, A16, C01, C02, C03, X01, X02, X03.

Việc cần làm:

1. Pro hết giờ cloud: Home (Q01), danh sách kênh với tự động ghi tạm dừng (Q02), sau khi mua thêm tự bật lại (Q04), hết giờ khi đang ghi thì dừng an toàn (Q05). Sửa chữ: "Mua thêm giờ" thay cho "Mua Cloud Pack".
2. Máy có bản ghi trên máy của tài khoản khác (A16): cảnh báo, không nhập, không đổi chủ.
3. Luồng xin đồng ý quảng cáo C01–C03: dựng phần màn giải thích trước lời nhắc hệ thống; logic lấy từ `AdsService.consentState`. Pro bỏ qua toàn bộ.
4. Chữ 200% cho Home, màn đang ghi, màn mua giờ (X01–X03): không có hộp chứa chữ cố định chiều cao, đồng hồ giới hạn 1,5 lần, nút chính dính đáy.
5. Rà toàn bộ theo `docs/v2/design/docs/QA.md`.
6. Dọn: xoá chuỗi ARB không còn dùng, màn và widget cũ không còn route nào trỏ tới, mock cũ. Cập nhật `apps/mobile/README.md` cho đúng hiện trạng.

Không dựng: A03-social, A14, S10, S10b, M14 (để đợt sau hoặc đã bỏ).
