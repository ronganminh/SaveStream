# SaveStream V2 — Hợp đồng API bổ sung

File này mô tả phần API **thêm mới hoặc thay đổi** cho V2, trên nền hợp đồng hiện có ở `docs/openapi.yaml`. Track B đưa nội dung này vào `docs/openapi.yaml` ở phase B0; từ lúc đó `docs/openapi.yaml` là nguồn chuẩn và file này phải khớp với nó.

Quy ước giữ nguyên như API hiện tại: tiền tố `/v1`, JSON, thời gian UTC ISO-8601, ID dạng chuỗi, phân trang cursor (`items` + `pagination.next_cursor` / `has_more`), lỗi dạng `{"error": {"code", "message", "request_id", "retryable", "details"}}`, Bearer access token. Trong `docs/openapi.yaml`, kiểu mà tài liệu này gọi là `WatchResponse` và `RecordingResponse` dùng tên schema hiện có là `Watch` và `Recording`; B0 mở rộng schema cũ, không tạo kiểu trùng.

Đơn vị: backend lưu **credit**, 1 credit = 1 phút cloud. Mọi trường thời lượng cloud trong API tính bằng **phút** (`*_minutes`); app tự đổi ra giờ để hiển thị.

## 1. Gói và quyền (entitlement)

### `GET /v1/me/entitlement`

```json
{
  "plan": "free",
  "has_purchased": false,
  "email_verified": true,
  "can_auto_record": true,
  "trial_recording": true,
  "cloud_minutes_available": 10,
  "limits": {
    "max_watches": 3,
    "max_concurrent_cloud_recordings": 1,
    "cloud_retention_days": 7
  },
  "watch_count": 2,
  "local": {
    "enabled": true,
    "unlimited": false,
    "daily_minutes": 10,
    "minutes_remaining": 6,
    "resets_at": "2026-10-04T00:00:00Z",
    "rewards_used_today": 2,
    "rewards_cap_per_day": 8,
    "minutes_per_reward": 10,
    "extensions_cap_per_recording": 4
  },
  "last_pack_name": null,
  "last_pack_minutes": null,
  "cloud_minutes_cycle_total": 10,
  "trial_used": true,
  "updated_at": "2026-10-03T13:05:00Z"
}
```

Quy tắc:

- `plan = "pro"` khi tài khoản có ít nhất một đơn mua đã thanh toán **và** số dư credit khả dụng > 0. Ngược lại là `"free"`.
- 10 credit dùng thử khi xác minh email **không** làm tài khoản thành Pro, nhưng được ghi thật (quyết định 2026-10-16): `trial_recording = true` khi chưa mua, email đã xác minh và số dư khả dụng > 0.
- `can_auto_record = plan == "pro" || trial_recording`: bật được Auto-record. Khi chưa mua và chưa xác minh email, bật Auto-record trả `403 EMAIL_NOT_VERIFIED`; hết credit trả `403 PLAN_REQUIRED`.
- Pro: `max_watches = 20`, `max_concurrent_cloud_recordings = 3`.
- Free đang dùng thử: `max_watches = 3`, `max_concurrent_cloud_recordings = 1`. Free hết credit hoặc chưa xác minh email: `max_concurrent_cloud_recordings = 0`.
- Bản ghi luôn bị giới hạn theo số dư; khi credit hết, bản ghi dừng, hoàn tất bình thường và tính đúng phần đã giữ chỗ (số dư không âm). Thông báo `cloud_minutes_exhausted` (in-app + email nếu bật) dẫn tới `/billing`.
- `has_purchased = true` khi còn ít nhất một đơn ở trạng thái paid hợp lệ theo `PAID_ORDER_STATUSES`; đơn đã hoàn tiền toàn bộ không tính. `cloud_retention_days` theo lịch sử mua hiện có của backend: `30` khi `has_purchased = true`, ngược lại `7`. Vì vậy tài khoản đã mua nhưng vừa hết số dư có thể có `plan = "free"` đồng thời `cloud_retention_days = 30`.
- `local.enabled`: tài khoản có được ghi trên máy không. `local.unlimited`: không giới hạn phút, khi đó app bỏ qua các trường phút và phần thưởng.
- Free: `enabled = true`, `unlimited = false`.
- Pro: `enabled = true`, `unlimited = true` (mặc định hiện tại). Backend đổi được bằng cấu hình `SAVESTREAM_PRO_LOCAL_RECORDING` (`unlimited` hoặc `disabled`); app **phải đọc hai trường này**, không tự suy ra từ `plan`.
- Phút Free reset lúc 00:00 UTC. App chỉ hiển thị đếm ngược theo giờ máy.
- `last_pack_name` / `last_pack_minutes`: tên và số phút của gói mua gần nhất còn ở trạng thái `paid` hoặc `partially_refunded`; `null` khi chưa mua (đơn đã hoàn tiền toàn bộ không tính).
- `cloud_minutes_cycle_total`: số N trong thanh "còn X phút / N". Bằng số dư (posted) ngay sau lần nạp gần nhất (mua gói; chưa mua thì lần cấp dùng thử) cộng các phút được cấp thêm sau đó (quảng cáo thưởng, mã khuyến mãi, hỗ trợ cộng). Ghi hình chỉ làm giảm số dư nên số dư không bao giờ vượt N. `null` khi chưa từng được nạp. Chọn cách này thay vì "tổng phút đã mua" (thanh vô nghĩa sau nhiều lần mua) hay "cỡ gói cuối" (số dư có thể lớn hơn gói vì còn dư từ trước).
- `trial_used`: đã từng được cấp phút dùng thử (một lần mỗi tài khoản), dù đã dùng hết hay chưa.

## 2. Kênh theo dõi (watch)

Thêm trường vào `WatchResponse`:

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `notify_on_live` | bool | Gửi push khi kênh LIVE. Mặc định `true`. Tắt chỉ tắt push, backend vẫn theo dõi. |
| `auto_record_state` | `"off"` \| `"active"` \| `"paused_no_cloud_minutes"` \| `"waiting_for_cloud_slot"` | Trạng thái tự động ghi để hiển thị. |
| `pending_verification_code` | string \| null | Mã xác minh bio đang chờ kiểm tra (giống `GET /v1/watches/{id}/verification`). `null` khi kênh đã xác minh hoặc không còn mã chưa hết hạn. Đọc kênh không bao giờ tạo mã mới. |
| `pending_verification_expires_at` | datetime \| null | Lúc `pending_verification_code` hết hạn. |
| `recording_count` | int \| null | Số bản ghi chưa xoá của người dùng cho kênh này (như danh sách `GET /v1/recordings`, mọi trạng thái), khớp theo username hoặc room id. `/v1/watches` luôn trả số; `null` ở chỗ không tính (admin). |
| `total_recorded_seconds` | int \| null | Tổng `duration_seconds` của các bản ghi trên. |
| `last_live_duration_seconds` | int \| null | `duration_seconds` của bản ghi `completed`/`stopped` kết thúc gần nhất của kênh. `null` khi chưa có. |

- `CreateWatchRequest` và `UpdateWatchRequest` nhận thêm `notify_on_live` (tuỳ chọn).
- Bật `auto_record = true` với tài khoản Free: trả `403` mã `PLAN_REQUIRED`.
- Tạo kênh khi đã đủ giới hạn: trả `409` mã `WATCH_LIMIT_REACHED`, kèm `error.details = {"limit": 3, "plan": "free"}`.
- Kênh ở trạng thái tạm dừng vẫn tính vào giới hạn.
- Tài khoản Free đang có nhiều hơn 3 kênh (tồn từ trước): giữ nguyên, không tạo thêm được.
- Sau khi mua thêm giờ, các kênh đang `paused_insufficient_credit` tự chuyển về `active`. Không ghi bù phần đã bỏ lỡ.

## 3. Bản ghi cloud (recording)

Thêm giá trị trạng thái:

| Trạng thái | Ý nghĩa |
|---|---|
| `waiting_for_cloud_slot` | Kênh đang LIVE nhưng người dùng đã dùng đủ số slot cloud. Chờ theo thứ tự vào trước ra trước. |
| `missed_no_cloud_slot` | LIVE kết thúc khi vẫn đang chờ slot. Trạng thái kết thúc, không tính phút. |

Thêm trường vào `RecordingResponse`:

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `engine` | `"cloud"` | Luôn là `cloud` với bản ghi do backend tạo. |
| `expires_at` | datetime \| null | Thời điểm file cloud bị xoá theo thời hạn lưu. |
| `minutes_charged` | int | Số phút đã trừ. Bản ghi lỗi: 0 (hoàn toàn bộ). |
| `queue_position` | int \| null | Vị trí trong hàng chờ khi `waiting_for_cloud_slot`. |
| `failure_reason` | string \| null | Lý do thất bại bằng tiếng Anh dễ hiểu, ánh xạ từ `error.code` (hoặc trạng thái `missed_no_cloud_slot`). Chỉ có khi `failed` hoặc `missed_no_cloud_slot`, còn lại `null`. Ứng dụng hiển thị trường này thay cho `error.message`. |
| `failure_guidance` | string \| null | Gợi ý bước tiếp theo đi kèm `failure_reason` (có câu báo không bị trừ phút khi `minutes_charged` = 0). |

`error` giữ nguyên (mã và thông điệp kỹ thuật) để tương thích ngược. Bảng ánh xạ nằm ở `backend/src/app/application/recordings/failure_reasons.py` và `docs/api/recordings.md`.

`actions.can_retry` chỉ `true` khi kênh còn LIVE và lỗi có thể thử lại.

## 4. Ghi trên máy (local) của tài khoản Free

Ghi trên máy không tốn hạ tầng ghi của máy chủ. Backend chỉ làm ba việc: cấp phút, trả địa chỉ luồng, và lưu metadata để đồng bộ giữa các thiết bị.

### `POST /v1/local-recordings/sessions`

Bắt đầu một phiên ghi trên máy. Header `Idempotency-Key` bắt buộc (UUID).

```json
{ "watch_id": "wat_123", "device_id": "dev_abc", "reward_id": null }
```

Trả `201`:

```json
{
  "session_id": "lrs_123",
  "granted_seconds": 360,
  "lease_expires_at": "2026-10-03T13:28:00Z",
  "stream": { "url": "https://...", "format": "flv", "headers": {"User-Agent": "..."} }
}
```

- `granted_seconds` lấy từ phút Free còn lại trong ngày, hoặc từ phần thưởng quảng cáo nếu có `reward_id` hợp lệ.
- Hết phút và không có phần thưởng: `402` mã `FREE_MINUTES_EXHAUSTED`.
- Tài khoản `local.unlimited`: `granted_seconds` là một lease dài (mặc định 4 giờ), app gọi `extend` không kèm `reward_id` để nối tiếp; không trừ phút Free.
- Tài khoản `local.enabled = false`: `403` mã `LOCAL_RECORDING_DISABLED`.
- Kênh không LIVE: `409` mã `CREATOR_NOT_LIVE`.
- Đã có phiên ghi trên máy đang chạy và chưa mở ô thứ 2: `409` mã `LOCAL_SLOT_BUSY`.
- `stream.format` là `flv` hoặc `hls`. `stream.url` có thời hạn ngắn; app không lưu lại.

### `POST /v1/local-recordings/sessions/{session_id}/extend`

```json
{ "reward_id": "rwd_123" }
```

Cộng thêm `minutes_per_reward` phút cho phiên đang chạy. Quá 4 lần gia hạn cho một phiên: `409` mã `EXTENSION_LIMIT_REACHED`. Thành công trả `204` không có body; với `local.unlimited`, `reward_id` có thể bỏ trống.

### `POST /v1/local-recordings/sessions/{session_id}/finish`

```json
{
  "recorded_seconds": 372,
  "size_bytes": 224395264,
  "end_reason": "user_stopped",
  "status": "completed"
}
```

- `end_reason`: `user_stopped`, `live_ended`, `free_minutes_exhausted`, `storage_low`, `interrupted`, `error`.
- `status`: `completed`, `partial`, `recovered`, `failed`.
- Backend trừ phút theo `recorded_seconds` (làm tròn lên phút), tối đa bằng `granted_seconds`. Khoảng mất kết nối không ghi được thì không tính.
- Gọi lại nhiều lần với cùng nội dung cho cùng kết quả. Thành công trả `204` không có body.

### `GET /v1/local-recordings`

Danh sách metadata các bản ghi trên máy của tài khoản, từ mọi thiết bị, phân trang cursor.

```json
{
  "items": [{
    "id": "lrs_123",
    "watch_id": "wat_123",
    "creator": { "platform": "tiktok", "username": "linastudio", "display_name": "Lina Studio", "avatar_url": null },
    "device_id": "dev_abc",
    "device_name": "Pixel 8",
    "started_at": "2026-10-03T13:22:00Z",
    "recorded_seconds": 372,
    "size_bytes": 224395264,
    "status": "completed"
  }],
  "pagination": { "next_cursor": null, "has_more": false }
}
```

### `DELETE /v1/local-recordings/{id}`

Chỉ thiết bị nguồn gọi (gửi `device_id` trong query). Thiết bị khác: `403` mã `NOT_SOURCE_DEVICE`. Thành công trả `204` không có body.

## 5. Quảng cáo thưởng (rewarded)

### `POST /v1/rewards`

Tạo một ý định nhận thưởng trước khi hiện quảng cáo.

```json
{ "purpose": "local_minutes", "session_id": null }
```

Trả `201`: `{ "reward_id": "rwd_123", "ssv_user_id": "usr_1", "ssv_custom_data": "rwd_123", "expires_at": "..." }`. App truyền `ssv_user_id` và `ssv_custom_data` vào SDK quảng cáo để mạng quảng cáo gọi lại máy chủ.

- `purpose`: `local_minutes` (thêm phút ghi) hoặc `local_slot` (mở ô ghi thứ 2; cần 2 phần thưởng).
- Đã đủ 8 phần thưởng hợp lệ trong ngày: `409` mã `REWARD_DAILY_CAP_REACHED`.
- Tạm khoá vì nhiều lần không hợp lệ: `429` mã `REWARD_LOCKED`, `error.details` có `locked_until` và `retry_after_seconds`.
- `purpose = cloud_minutes`: bắt đầu quá `SAVESTREAM_REWARD_INTENTS_PER_HOUR` quảng cáo trong 1 giờ trượt: `429` mã `RATE_LIMITED`, `error.details = {"retry_after_seconds": 600, "limit": 20, "window_seconds": 3600}`. `retry_after_seconds` tính từ lúc ý định cũ nhất cần thiết ra khỏi cửa sổ.
- Mọi phản hồi `429` có `error.details.retry_after_seconds` đều kèm header `Retry-After` (giây) cùng giá trị.

### `GET /v1/rewards/{reward_id}`

`{ "reward_id": "rwd_123", "status": "pending" }`, với `status` là `pending`, `valid`, `invalid`, `expired`. App hỏi lại mỗi 2 giây, tối đa khoảng 15 giây, rồi hiện trạng thái "xác nhận chậm".

### `GET /v1/webhooks/admob-ssv`

Điểm nhận gọi lại xác minh phía máy chủ của mạng quảng cáo. Kiểm tra chữ ký, đánh dấu phần thưởng `valid`. Chỉ phần thưởng `valid` mới tính vào giới hạn 8 mỗi ngày. Tham số query do AdMob quy định và được B4 kiểm từ request thô; B0 không đóng băng từng tên tham số. Thành công trả `200` theo yêu cầu của AdMob SSV.

## 6. Mua trong app

### `GET /v1/billing/packages` (thay đổi)

Mỗi gói thêm:

```json
{ "store_product_ids": { "app_store": "savestream.hours.50", "google_play": "savestream.hours.50" }, "cloud_minutes": 3000, "featured": false }
```

`featured`: gói được làm nổi bật ("Phổ biến nhất"). Theo cấu hình `SAVESTREAM_FEATURED_PACKAGE_CODES` (danh sách `code` cách nhau dấu phẩy); mặc định rỗng, staging/production mặc định `standard`. Không đổi giá. `GET /v1/public/pricing` cũng trả `featured` cho mỗi gói.

Mã sản phẩm: `savestream.hours.50`, `savestream.hours.150`, `savestream.hours.400`, loại mua một lần dùng dần (consumable).

### `POST /v1/billing/store-purchases`

```json
{
  "platform": "app_store",
  "product_id": "savestream.hours.50",
  "transaction_id": "2000000123456789",
  "receipt": "<chuỗi JWS của App Store hoặc purchase token của Google Play>",
  "price_amount_micros": 24990000,
  "price_currency_code": "USD"
}
```

`price_amount_micros` / `price_currency_code` (tuỳ chọn): giá Google Play hiện cho người dùng (`ProductDetails`). Chỉ để hiển thị: lưu vào đơn dưới tên `client_price_*`, không xác minh với Google, không dùng để tính tiền. `purchases.products.get` của Google không trả giá nên backend không có giá đã thu thật.

Trả `200`:

```json
{ "status": "credited", "payment_order_id": "ord_123", "cloud_minutes_added": 3000, "cloud_minutes_available": 3000 }
```

- Backend xác minh với Apple hoặc Google rồi mới cộng. App không tự cộng.
- Cùng `transaction_id` gửi lại: trả kết quả cũ, không cộng lần hai.
- `status`: `credited`, `pending` (store chưa xác nhận), `rejected`.
- Hoá đơn không hợp lệ: `422` mã `STORE_RECEIPT_INVALID`.
- Hoàn tiền từ store (nhận qua thông báo máy chủ của Apple/Google): backend trừ lại số phút tương ứng, không để số dư âm.

### `GET /v1/billing/payment-orders` (thay đổi)

Mỗi đơn thêm:

```json
{ "store_order_id": "GPA.3301-2345-6789-01234", "client_price_amount_micros": 24990000, "client_price_currency": "USD" }
```

- `store_order_id`: `orderId` Google Play trả khi xác minh. `null` với đơn web, mua bằng mã khuyến mãi của Play (không có orderId) và đơn cũ chưa được xác minh lại. `provider_reference` giữ nguyên (với Google Play là hash của purchase token).
- `client_price_*`: giá app báo khi mua (xem trên); `null` khi app không gửi. `amount` vẫn là giá niêm yết của gói.

### `GET /v1/credits/transactions` (thay đổi)

Mỗi dòng thêm `store_order_id`, `package_name` (dòng của đơn mua/hoàn tiền) và `recording_channel_username`, `recording_duration_seconds` (dòng của bản ghi: giữ chỗ, trừ, trả lại). Các trường không áp dụng là `null`. Backend nạp bằng một truy vấn cho mỗi loại, không truy vấn theo từng dòng.

## 7. Thiết bị và push

### `PUT /v1/me/devices/{device_id}`

```json
{ "platform": "android", "push_token": "fcm-token", "device_name": "Pixel 8", "app_version": "2.0.0", "locale": "vi" }
```

Tạo hoặc cập nhật. `push_token` có thể null khi người dùng chưa cấp quyền. Thành công trả `204` không có body.

### `DELETE /v1/me/devices/{device_id}`

Gọi khi đăng xuất. Thành công trả `204` không có body.

### Loại thông báo mới

Thêm vào `NotificationKind`: `creator_live`, `recording_missed`, `recording_expiring`, `cloud_minutes_exhausted`, `free_minutes_low`, `purchase_completed`.

`resource_type` thêm giá trị `watch`.

### `GET` / `PATCH /v1/me/notification-preferences` (thay đổi)

Thêm các trường bool: `creator_live`, `recording_expiring`, `free_minutes_low`, `marketing`. Ba trường cũ giữ nguyên. Thông báo giao dịch luôn gửi, không có công tắc.

## 8. Trạng thái ứng dụng

### `GET /v1/app/status` (không cần đăng nhập)

```json
{
  "min_supported_version": { "android": "2.0.0", "ios": "2.0.0" },
  "maintenance": { "active": false, "eta": null }
}
```

App so phiên bản để hiện màn bắt buộc cập nhật, và hiện màn bảo trì khi `maintenance.active = true`.

## 9. Hỗ trợ và khuyến mãi (do Track D triển khai)

### `POST /v1/support/reports`

Màn "Báo lỗi" của app gửi lên. App lưu nháp và gửi lại khi có mạng.

```json
{ "message": "Recording stopped after 20 minutes", "recording_id": "rec_123", "diagnostics": { "app_version": "2.0.0", "os": "Android 15", "recorder_state": "…", "error_code": "…" } }
```

Trả `201`: `{ "report_id": "rpt_123" }`. Không bao giờ gửi file video.

### `POST /v1/credits/redeem`

`{ "code": "WELCOME50" }` → `200`: `{ "cloud_minutes_added": 3000, "cloud_minutes_available": 3000 }`. Mã sai, hết hạn, hết lượt hoặc đã dùng: `409` mã `PROMO_CODE_INVALID`. Giờ từ mã khuyến mãi không làm tài khoản thành Pro trừ khi mã được đánh dấu "tính như đã mua".

## 10. Mã lỗi mới

| Mã | HTTP | Khi nào |
|---|---|---|
| `PLAN_REQUIRED` | 403 | Tính năng cần Pro |
| `WATCH_LIMIT_REACHED` | 409 | Đủ số kênh theo gói |
| `FREE_MINUTES_EXHAUSTED` | 402 | Hết phút Free trong ngày |
| `CREATOR_NOT_LIVE` | 409 | Kênh không LIVE khi bắt đầu ghi trên máy |
| `LOCAL_SLOT_BUSY` | 409 | Đang có phiên ghi trên máy khác |
| `EXTENSION_LIMIT_REACHED` | 409 | Quá 4 lần gia hạn một phiên |
| `REWARD_DAILY_CAP_REACHED` | 409 | Đủ 8 phần thưởng trong ngày |
| `REWARD_LOCKED` | 429 | Tạm khoá phần thưởng (`details.retry_after_seconds`, header `Retry-After`) |
| `STORE_RECEIPT_INVALID` | 422 | Hoá đơn store không hợp lệ |
| `NOT_SOURCE_DEVICE` | 403 | Xoá bản ghi trên máy từ thiết bị khác |
| `LOCAL_RECORDING_DISABLED` | 403 | Tài khoản không được ghi trên máy |
| `NOT_IMPLEMENTED` | 501 | Route V2 đã được B0 đóng băng contract nhưng phase sở hữu chưa triển khai; chỉ dùng trong giai đoạn rollout |
| `CREATOR_BLOCKED` | 403 | Kênh bị chặn toàn hệ thống (khiếu nại) |
| `PROMO_CODE_INVALID` | 409 | Mã khuyến mãi không dùng được |
| `CHANNEL_NOT_FOUND` | 404 | `POST /v1/live-status`: trang hồ sơ TikTok báo không có tài khoản với username này. TikTok lỗi, hết giờ hoặc không trả lời rõ vẫn là `503 STREAM_UNAVAILABLE`. Kênh có thật nhưng không LIVE (kể cả chưa từng LIVE) trả `200` với `live_status: "offline"`, `room_id: null` |

## 11. Không thay đổi

Auth, phiên đăng nhập (`/v1/me/sessions`), số dư và sổ credit, luồng bản ghi cloud hiện có, artifact và link tải, SSE tiến độ bản ghi, xoá tài khoản, thanh toán web qua Lemon Squeezy.
