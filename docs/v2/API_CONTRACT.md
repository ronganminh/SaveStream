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
  "cloud_minutes_available": 0,
  "limits": {
    "max_watches": 3,
    "max_concurrent_cloud_recordings": 0,
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
  "updated_at": "2026-10-03T13:05:00Z"
}
```

Quy tắc:

- `plan = "pro"` khi tài khoản có ít nhất một đơn mua đã thanh toán **và** số dư credit khả dụng > 0. Ngược lại là `"free"`.
- 10 credit dùng thử khi xác minh email **không** làm tài khoản thành Pro.
- Pro: `max_watches = 20`, `max_concurrent_cloud_recordings = 3`, `cloud_retention_days = 30`.
- Free: `max_watches = 3`, `max_concurrent_cloud_recordings = 0` trên mobile. Web vẫn cho tài khoản Free dùng credit dùng thử để ghi cloud thủ công; quy tắc đó do web và backend xử lý, không qua trường này.
- `local.enabled`: tài khoản có được ghi trên máy không. `local.unlimited`: không giới hạn phút, khi đó app bỏ qua các trường phút và phần thưởng.
- Free: `enabled = true`, `unlimited = false`.
- Pro: `enabled = true`, `unlimited = true` (mặc định hiện tại). Backend đổi được bằng cấu hình `SAVESTREAM_PRO_LOCAL_RECORDING` (`unlimited` hoặc `disabled`); app **phải đọc hai trường này**, không tự suy ra từ `plan`.
- Phút Free reset lúc 00:00 UTC. App chỉ hiển thị đếm ngược theo giờ máy.

## 2. Kênh theo dõi (watch)

Thêm trường vào `WatchResponse`:

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `notify_on_live` | bool | Gửi push khi kênh LIVE. Mặc định `true`. Tắt chỉ tắt push, backend vẫn theo dõi. |
| `auto_record_state` | `"off"` \| `"active"` \| `"paused_no_cloud_minutes"` \| `"waiting_for_cloud_slot"` | Trạng thái tự động ghi để hiển thị. |

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
- Tạm khoá vì nhiều lần không hợp lệ: `429` mã `REWARD_LOCKED`.

### `GET /v1/rewards/{reward_id}`

`{ "reward_id": "rwd_123", "status": "pending" }`, với `status` là `pending`, `valid`, `invalid`, `expired`. App hỏi lại mỗi 2 giây, tối đa khoảng 15 giây, rồi hiện trạng thái "xác nhận chậm".

### `GET /v1/webhooks/admob-ssv`

Điểm nhận gọi lại xác minh phía máy chủ của mạng quảng cáo. Kiểm tra chữ ký, đánh dấu phần thưởng `valid`. Chỉ phần thưởng `valid` mới tính vào giới hạn 8 mỗi ngày. Tham số query do AdMob quy định và được B4 kiểm từ request thô; B0 không đóng băng từng tên tham số. Thành công trả `204`.

## 6. Mua trong app

### `GET /v1/billing/packages` (thay đổi)

Mỗi gói thêm:

```json
{ "store_product_ids": { "app_store": "savestream.hours.50", "google_play": "savestream.hours.50" }, "cloud_minutes": 3000 }
```

Mã sản phẩm: `savestream.hours.50`, `savestream.hours.150`, `savestream.hours.400`, loại mua một lần dùng dần (consumable).

### `POST /v1/billing/store-purchases`

```json
{
  "platform": "app_store",
  "product_id": "savestream.hours.50",
  "transaction_id": "2000000123456789",
  "receipt": "<chuỗi JWS của App Store hoặc purchase token của Google Play>"
}
```

Trả `200`:

```json
{ "status": "credited", "payment_order_id": "ord_123", "cloud_minutes_added": 3000, "cloud_minutes_available": 3000 }
```

- Backend xác minh với Apple hoặc Google rồi mới cộng. App không tự cộng.
- Cùng `transaction_id` gửi lại: trả kết quả cũ, không cộng lần hai.
- `status`: `credited`, `pending` (store chưa xác nhận), `rejected`.
- Hoá đơn không hợp lệ: `422` mã `STORE_RECEIPT_INVALID`.
- Hoàn tiền từ store (nhận qua thông báo máy chủ của Apple/Google): backend trừ lại số phút tương ứng, không để số dư âm.

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

## 9. Mã lỗi mới

| Mã | HTTP | Khi nào |
|---|---|---|
| `PLAN_REQUIRED` | 403 | Tính năng cần Pro |
| `WATCH_LIMIT_REACHED` | 409 | Đủ số kênh theo gói |
| `FREE_MINUTES_EXHAUSTED` | 402 | Hết phút Free trong ngày |
| `CREATOR_NOT_LIVE` | 409 | Kênh không LIVE khi bắt đầu ghi trên máy |
| `LOCAL_SLOT_BUSY` | 409 | Đang có phiên ghi trên máy khác |
| `EXTENSION_LIMIT_REACHED` | 409 | Quá 4 lần gia hạn một phiên |
| `REWARD_DAILY_CAP_REACHED` | 409 | Đủ 8 phần thưởng trong ngày |
| `REWARD_LOCKED` | 429 | Tạm khoá phần thưởng |
| `STORE_RECEIPT_INVALID` | 422 | Hoá đơn store không hợp lệ |
| `NOT_SOURCE_DEVICE` | 403 | Xoá bản ghi trên máy từ thiết bị khác |
| `LOCAL_RECORDING_DISABLED` | 403 | Tài khoản không được ghi trên máy |\n| `NOT_IMPLEMENTED` | 501 | Route V2 đã được B0 đóng băng contract nhưng phase sở hữu chưa triển khai; chỉ dùng trong giai đoạn rollout |

## 10. Không thay đổi

Auth, phiên đăng nhập (`/v1/me/sessions`), số dư và sổ credit, luồng bản ghi cloud hiện có, artifact và link tải, SSE tiến độ bản ghi, xoá tài khoản, thanh toán web qua Lemon Squeezy.
