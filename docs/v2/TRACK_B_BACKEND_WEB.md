# Track B — Backend và Web

Đọc [README.md](README.md), [DECISIONS.md](DECISIONS.md) và [API_CONTRACT.md](API_CONTRACT.md) trước.

**Mục tiêu:** backend hỗ trợ đủ mô hình V2 (Free/Pro theo giờ đã mua, giới hạn theo gói, hàng chờ slot, ghi trên máy, quảng cáo thưởng, mua trong app, push), và web khớp với các quyết định mới. Backend và web đang chạy production với mô hình credit: **mọi thay đổi phải tương thích ngược**, web hiện tại không được hỏng ở bất kỳ phase nào.

**Phạm vi file:** `backend/**`, `docs/openapi.yaml`, `docs/api/**`, `docs/v2/API_CONTRACT.md`, `apps/web/**`, workflow backend và web. **Không đụng `apps/mobile/**`, `deploy/**`, secret, hay dữ liệu production.**

## Tiến độ

- [x] B0 — Đưa hợp đồng V2 vào OpenAPI
- [ ] B1 — Gói Free/Pro và giới hạn theo gói
- [ ] B2 — Hàng chờ slot cloud và tự bật lại sau khi mua
- [ ] B3 — Thiết bị, push và loại thông báo mới
- [ ] B4 — Ghi trên máy: phút Free, phần thưởng quảng cáo, đồng bộ metadata
- [ ] B5 — Mua trong app (App Store, Google Play)
- [ ] B6 — Trạng thái ứng dụng, hạn lưu, thông báo sắp hết hạn
- [ ] B7 — Web theo V2
- [ ] B8 — Năng lực máy chủ và tài liệu vận hành

## Kiểm tra (chạy trong `backend` trước khi mở PR)

```bash
python -m pip install --no-deps -r requirements.lock
python -m pip install --no-deps --no-build-isolation -e .
ruff check src tests
mypy src/config.py src/engine src/adapters src/app src/http_utils/http_client.py src/utils/logger_manager.py src/utils/dependencies.py
pytest
SAVESTREAM_ENVIRONMENT=test SAVESTREAM_DATABASE_URL=sqlite+aiosqlite:///./ci.db alembic upgrade head
SAVESTREAM_ENVIRONMENT=test SAVESTREAM_DATABASE_URL=sqlite+aiosqlite:///./ci.db alembic downgrade base
```

Web (chạy ở gốc repo): `npm install`, `npm --workspace apps/web run format`, `npm --workspace apps/web run lint`, `npm run typecheck`, toàn bộ `npm --workspace apps/web run test:*` liệt kê trong `.github/workflows/web-ci.yml`, rồi `npm run build`.

CI phải xanh: `Backend CI` (Python 3.11 và 3.12), `Backend E2E`, `Mobile Backend E2E` (chạy app với backend thật; nếu phase làm nó đỏ thì phase đó đã phá tương thích ngược), và `Web CI` khi đụng tới web.

## Quy tắc chung cho mọi phase của Track B

1. **Hợp đồng trước, code sau.** Endpoint hoặc trường mới phải có trong `docs/openapi.yaml` (file này có test đối chiếu `operationId` trong `backend/tests/test_phase*_contract.py`). Thêm test hợp đồng cho phần mới theo đúng mẫu đó.
2. **Chỉ thêm, không phá.** Trường mới có giá trị mặc định; không đổi tên hay xoá trường, trạng thái, mã lỗi đang có. App mobile bản cũ và web hiện tại phải chạy tiếp được.
3. **Migration Alembic** cho mọi thay đổi bảng, chạy được cả `upgrade head` lẫn `downgrade base`, an toàn với dữ liệu đang có (cột mới cho phép null hoặc có mặc định).
4. **Cấu hình qua biến môi trường** trong `src/app/settings.py`, có mặc định an toàn. Tính năng cần khoá bên ngoài (Apple, Google, FCM, AdMob) phải **tắt mặc định** và không làm hỏng khởi động khi thiếu khoá. Ghi biến mới vào `deploy/vps/production.env` là việc của chủ repo; chỉ liệt kê trong PR.
5. **Bên ngoài nằm sau interface.** Xác minh hoá đơn, gửi push, kiểm chữ ký quảng cáo đều có interface cộng một bản giả dùng trong test. Test không gọi mạng thật.
6. **Tiền và phút:** mọi thao tác cộng trừ đi qua `CreditService` và sổ cái hiện có, có khoá idempotency. Không để số dư âm.
7. **Theo kiến trúc đang có:** `api/routes` → `application/<khu>/service.py` → `domain` → `infrastructure`. Đọc `backend/README.md`, `backend/PHASE*.md` và `docs/architecture.md` trước khi bắt đầu.
8. Tên file test theo mẫu `tests/test_v2_b<số>_<chủ đề>.py`.
9. **Track D (admin) cũng thêm migration song song.** Trước khi merge, rebase lên `main` và sửa `down_revision` để chuỗi migration chỉ có một đầu. Không sửa các file trong vùng admin của Track D (xem bảng quyền sở hữu trong README).

---

## B0 — Đưa hợp đồng V2 vào OpenAPI

**Phụ thuộc:** không. **Chặn:** C1.

1. Thêm toàn bộ endpoint, trường, trạng thái và mã lỗi trong `API_CONTRACT.md` vào `docs/openapi.yaml`, đánh dấu rõ phần nào chưa triển khai trong mô tả.
2. Thêm file `docs/api/v2.md` giải thích hành vi (giống các file `docs/api/*.md` hiện có), và sửa `API_CONTRACT.md` nếu trong lúc làm phát hiện chỗ không khớp với kiểu dữ liệu đang có.
3. Thêm route rỗng trả `501` mã `NOT_IMPLEMENTED` cho các endpoint mới, để test đối chiếu `operationId` qua và để mock từ OpenAPI dùng được.
4. Không thay đổi hành vi nào đang có.

Định nghĩa xong: `pytest` qua, test hợp đồng bao phủ các `operationId` mới, `npx -y @stoplight/prism-cli@5 mock docs/openapi.yaml` khởi động được.

---

## B1 — Gói Free/Pro và giới hạn theo gói

**Phụ thuộc:** B0.

1. **Suy ra gói:** Pro khi có ít nhất một đơn đã thanh toán (dùng lại logic `PAID_ORDER_STATUSES` trong `application/recordings/retention.py`) **và** số dư khả dụng > 0. Viết thành một service dùng chung, không rải điều kiện ở nhiều nơi.
2. **`GET /v1/me/entitlement`** theo hợp đồng. Khối `local` ở phase này trả giá trị mặc định (đủ 10 phút, 0 phần thưởng); B4 làm thật.
3. **Giới hạn kênh theo gói:** Free 3, Pro 20, thay cho giới hạn chung trong `application/quotas/service.py`. Kênh tạm dừng vẫn tính. Tài khoản Free đang có hơn 3 kênh: giữ nguyên, chặn tạo thêm. Lỗi `WATCH_LIMIT_REACHED` kèm `details`.
4. **Ghi cloud song song:** Pro 3 (`WATCH_MAX_CONCURRENT_RECORDINGS_PER_USER` và `QUOTA_MAX_ACTIVE_RECORDINGS_PER_USER` theo gói).
5. **Tự động ghi chỉ cho Pro:** bật `auto_record` với Free trả `403 PLAN_REQUIRED`. **Ngoại lệ tương thích:** tài khoản Free còn credit dùng thử vẫn được ghi cloud **thủ công** qua `POST /v1/recordings` (web đang dùng cho trải nghiệm 10 phút). Bộ lập lịch không tự ghi cho tài khoản Free.
6. Tài khoản đang có `auto_record = true` mà là Free: giữ giá trị trong DB, bộ lập lịch bỏ qua, `auto_record_state` trả `off`.
7. Trường `auto_record_state` trong `WatchResponse` (ở phase này: `off`, `active`, `paused_no_cloud_minutes`).
8. Test: suy ra gói ở mọi tổ hợp (chưa mua, đã mua còn dư, đã mua hết, hoàn tiền), giới hạn kênh, tài khoản tồn từ trước, bộ lập lịch bỏ qua Free.

Lưu ý tương thích: `Mobile Backend E2E` đang tạo kênh có tự động ghi với tài khoản thử. Nếu job đó đỏ vì quy tắc mới, **sửa `apps/mobile/test/backend_connectivity_e2e_test.dart` và dữ liệu thử liên quan ngay trong PR này** (ngoại lệ số 3 trong README), ví dụ cho tài khoản thử có một đơn đã thanh toán, hoặc tạo kênh không bật tự động ghi. Không sửa file mobile nào khác.

---

## B2 — Hàng chờ slot cloud và tự bật lại sau khi mua

**Phụ thuộc:** B1.

1. Hiện tại `application/watches/scheduler.py` bỏ qua lặng lẽ khi người dùng đã đủ số bản ghi song song. Thay bằng: tạo bản ghi ở trạng thái `waiting_for_cloud_slot`, có `queue_position` theo thứ tự vào trước ra trước trong phạm vi người dùng.
2. Khi một bản ghi của người dùng kết thúc: lấy bản đang chờ lâu nhất; nếu kênh còn LIVE thì bắt đầu ghi, nếu không thì chuyển `missed_no_cloud_slot`.
3. Mỗi nhịp lập lịch: bản đang chờ mà kênh đã hết LIVE thì chuyển `missed_no_cloud_slot`. Không trừ phút cho bản bỏ lỡ.
4. `auto_record_state = waiting_for_cloud_slot` cho kênh tương ứng.
5. Thông báo trong app loại `recording_missed`.
6. **Tự bật lại sau khi mua:** khi số dư tăng do đơn thanh toán thành công (web hoặc store), mọi kênh `paused_insufficient_credit` của người dùng chuyển về `active`. Không ghi bù. Gắn vào chỗ cộng credit sau thanh toán, có test.
7. Cập nhật máy trạng thái bản ghi (`domain/recordings`) và test chuyển trạng thái. Các trạng thái mới không được làm hỏng SSE và các bộ lọc "đang hoạt động" hiện có: quyết định rõ `waiting_for_cloud_slot` có tính là "active" hay không (không tính vào số slot đang dùng) và ghi vào `docs/api/v2.md`.
8. Giới hạn toàn hệ thống (hàng đợi `recordings` của Celery đầy): bản ghi nằm ở `queued` như hiện tại; không đổi hành vi này.

---

## B3 — Thiết bị, push và loại thông báo mới

**Phụ thuộc:** B1.

1. Bảng thiết bị và `PUT` / `DELETE /v1/me/devices/{device_id}`. Xoá thiết bị khi phiên đăng nhập tương ứng bị thu hồi.
2. Trường `notify_on_live` trên kênh (mặc định `true`), nhận trong tạo và sửa kênh.
3. Mở rộng `NotificationKind` và tuỳ chọn thông báo theo hợp đồng mục 7. Migration thêm cột với mặc định `true`, riêng `marketing` mặc định `false`.
4. **Interface gửi push** `PushSender` với hai bản: `NoopPushSender` (mặc định) và `FcmPushSender` (FCM HTTP v1, bật bằng `SAVESTREAM_PUSH_PROVIDER=fcm` cùng thông tin tài khoản dịch vụ qua biến môi trường). Gửi qua worker Celery, có thử lại, gỡ token khi FCM báo token không còn hợp lệ.
5. Sinh thông báo `creator_live` khi bộ lập lịch phát hiện kênh chuyển sang LIVE: một lần cho mỗi phiên LIVE, chỉ khi `notify_on_live` và tuỳ chọn `creator_live` đều bật.
6. Nội dung push theo ngôn ngữ của thiết bị (`locale`), tối thiểu EN và VI. Dữ liệu kèm theo có `resource_type` và `resource_id` để app mở đúng màn.
7. Test với sender giả: đúng người nhận, không gửi trùng, tôn trọng công tắc.

Không cần tài khoản Firebase để hoàn thành phase này; bản thật chỉ cần chạy đúng với máy chủ giả trong test.

---

## B4 — Ghi trên máy: phút Free, phần thưởng quảng cáo, đồng bộ metadata

**Phụ thuộc:** B1.

1. **Sổ phút Free theo ngày:** 10 phút mỗi ngày mỗi tài khoản, reset 00:00 UTC, dùng chung cho mọi phiên (2 phiên cùng lúc thì trừ gấp đôi). Bảng riêng, không trộn vào sổ credit.
2. **Phiên ghi trên máy** theo hợp đồng mục 4: bắt đầu (cấp `granted_seconds` và địa chỉ luồng), gia hạn, kết thúc. Mỗi phiên là một "lease": app được ghi tối đa `granted_seconds` kể cả khi mất mạng hay phiên đăng nhập hết hạn giữa chừng.
3. **Địa chỉ luồng:** dùng engine phân giải nguồn có sẵn (`backend/src/engine`, `backend/ENGINE.md`) để lấy URL luồng và header cần thiết, **không** khởi chạy tiến trình ghi nào trên máy chủ. Có giới hạn tần suất cho endpoint này.
4. Trừ phút khi kết thúc theo `recorded_seconds`, làm tròn lên phút, không vượt `granted_seconds`. Phiên không gọi kết thúc trong vòng `lease_expires_at` cộng một khoảng đệm: tự đóng và trừ toàn bộ phần đã cấp.
5. **Phần thưởng:** `POST /v1/rewards`, `GET /v1/rewards/{id}`, và điểm nhận gọi lại `GET /v1/webhooks/admob-ssv`. Kiểm chữ ký bằng khoá công khai của mạng quảng cáo qua interface `RewardVerifier` (bản giả cho test; bản thật tải và lưu đệm khoá). Tắt mặc định bằng biến môi trường.
6. Quy tắc phần thưởng: 10 phút mỗi phần thưởng, gắn với phiên nhận nó, không cộng dồn; tối đa 4 lần gia hạn một phiên; tối đa 8 phần thưởng **hợp lệ** một ngày; phần thưởng `pending` chưa tính; nhiều lần `invalid` liên tiếp thì tạm khoá (`REWARD_LOCKED`). Gọi lại tới muộn sau khi app đã hết chờ: vẫn ghi nhận, phần thưởng dùng được trong 24 giờ.
7. Ô ghi thứ 2: mở bằng 2 phần thưởng `purpose = local_slot`, có thời hạn; thời hạn và số ô trả trong khối `local` của entitlement (thêm trường nếu cần, cập nhật hợp đồng).
8. **Đồng bộ metadata:** `GET /v1/local-recordings`, `DELETE /v1/local-recordings/{id}` (chỉ thiết bị nguồn). Không lưu file video nào của bản ghi trên máy lên máy chủ.
9. Khối `local` trong `GET /v1/me/entitlement` trả số thật.
10. **Pro ghi trên máy không giới hạn phút** (đã chốt): cấu hình `SAVESTREAM_PRO_LOCAL_RECORDING`, giá trị `unlimited` (mặc định) hoặc `disabled`. Với `unlimited`: không trừ phút Free, không cần phần thưởng, cấp lease dài và cho `extend` không kèm `reward_id`. Với `disabled`: trả `403 LOCAL_RECORDING_DISABLED`. Trả đúng `local.enabled` và `local.unlimited` trong entitlement. Test cả hai giá trị cấu hình.

---

## B5 — Mua trong app

**Phụ thuộc:** B1, B2 (để tự bật lại sau khi mua).

1. Thêm `store_product_ids` và `cloud_minutes` vào gói (`GET /v1/billing/packages`), seed cho 3 gói hiện có: `savestream.hours.50`, `.150`, `.400`.
2. `POST /v1/billing/store-purchases`: xác minh qua interface `StoreReceiptVerifier` với hai bản thật (App Store Server API với giao dịch ký JWS; Google Play Developer API với purchase token) và một bản giả cho test. Thông tin xác thực qua biến môi trường; tắt mặc định, khi tắt endpoint trả `503` như thanh toán web hiện tại.
3. Tạo `PaymentOrder` với nhà cung cấp `app_store` hoặc `google_play`, cộng credit qua sổ cái với khoá idempotency là `transaction_id`. Gửi lại cùng giao dịch không cộng lần hai.
4. Với Google Play: xác nhận (acknowledge) và tiêu thụ (consume) giao dịch sau khi cộng.
5. **Hoàn tiền và thu hồi:** nhận thông báo máy chủ của Apple (App Store Server Notifications V2) và Google (Real-time Developer Notifications) ở `/v1/webhooks/app-store` và `/v1/webhooks/google-play`, kiểm chữ ký, trừ lại số phút tương ứng (không âm), cập nhật trạng thái đơn `refunded`.
6. Đơn mua từ store hiện trong lịch sử đơn hiện có và làm tài khoản thành Pro theo quy tắc B1.
7. Thông báo `purchase_completed`.
8. Test: giao dịch hợp lệ, gửi lại, hoá đơn giả, sai sản phẩm, hoàn tiền khi đã tiêu hết phút.

Không cần tài khoản Apple/Google để hoàn thành phase; bản thật được kiểm bằng dữ liệu mẫu và máy chủ giả.

---

## B6 — Trạng thái ứng dụng, hạn lưu, thông báo sắp hết hạn

**Phụ thuộc:** B3.

1. `GET /v1/app/status` (không cần đăng nhập): phiên bản tối thiểu và trạng thái bảo trì, cấu hình bằng biến môi trường.
2. `expires_at`, `minutes_charged`, `engine` trên `RecordingResponse`, tính từ quy tắc lưu trữ hiện có (30 ngày nếu đã mua, 7 ngày nếu chưa).
3. Tác vụ định kỳ gửi thông báo `recording_expiring` một lần, khoảng 24 giờ trước khi hết hạn.
4. Thông báo `cloud_minutes_exhausted` một lần cho mỗi lần hết phút, và `free_minutes_low` khi phút Free trong ngày sắp hết (ngưỡng cấu hình được).

---

## B7 — Web theo V2

**Phụ thuộc:** B1, B2, B6.

1. Hiển thị "≈ X giờ" cạnh số credit ở trang giá, trang Credits và Billing.
2. Giới hạn kênh theo gói: hiện `n/3` hoặc `n/20`, xử lý `WATCH_LIMIT_REACHED` và `PLAN_REQUIRED` bằng lời mời mua giờ.
3. Trạng thái bản ghi mới (`waiting_for_cloud_slot`, `missed_no_cloud_slot`) có nhãn và mô tả, EN và VI.
4. Tài khoản Free: giải thích rõ 10 phút dùng thử, và rằng tự động ghi cần mua giờ.
5. Trang giá: bỏ mọi chỗ ngụ ý thuê bao; ghi mua một lần, không hết hạn, và có thể mua trong app mobile.
6. Trang Terms và Privacy: thêm quảng cáo trong bản Free của app mobile, mua trong app qua App Store và Google Play, và dữ liệu thiết bị dùng cho push. Nội dung pháp lý chỉ ghi "SaveStream", không ghi tên cá nhân. **Đánh dấu PR này cần chủ repo đọc duyệt trước khi merge.**
7. Cập nhật các script kiểm tra `apps/web/scripts/*-audit.mjs` cho khớp, không xoá kiểm tra.
8. Web mặc định tiếng Anh; chuỗi mới có cả bản tiếng Việt.

---

## B8 — Năng lực máy chủ và tài liệu vận hành

**Phụ thuộc:** B2.

1. Rà cấu hình ghi song song toàn hệ thống (`SAVESTREAM_RECORDING_CONCURRENCY`, số worker hàng đợi `recordings`): viết vào `backend/RUNBOOK.md` cách tính theo số tài khoản Pro (mỗi Pro tối đa 3 luồng) và chỉ số cần theo dõi.
2. Thêm chỉ số (metrics) cho: số bản đang chờ slot, số bản bỏ lỡ, số phiên ghi trên máy, tỉ lệ phần thưởng hợp lệ, số giao dịch store.
3. Viết `docs/v2/RELEASE_NOTES_BACKEND.md` liệt kê: biến môi trường mới, migration, thứ tự bật tính năng, và việc chủ repo cần làm tay khi deploy. Không sửa `deploy/vps/PRODUCTION_RELEASE.md` vì thư mục `deploy/` không được đụng.
4. Mở rộng `backend/scripts/release_smoke.py` để kiểm tra `GET /v1/app/status` và `GET /v1/me/entitlement`, giữ nguyên các kiểm tra cũ.
