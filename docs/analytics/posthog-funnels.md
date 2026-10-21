# PostHog: sự kiện phễu và cách tạo funnel

Project: **SaveStream** (US Cloud, project ID 677963), `https://us.posthog.com/project/677963`.

Funnel không tạo sẵn được bằng project token (`phc_...`): token này chỉ có quyền ghi sự kiện. Muốn
tạo insight bằng API thì cần personal API key (quyền `insight:write`), mà ta không dùng. Vì vậy hãy
tạo funnel một lần trong giao diện PostHog theo các bước dưới đây, mất khoảng 3 phút.

## Sự kiện

| Bước | Sự kiện | Gửi từ | Thuộc tính |
| ---- | ------- | ------ | ---------- |
| 1 | `signup_started` | Web: gửi form đăng ký, hoặc bấm Google/Apple ở /sign-up (hoặc bước đồng ý điều khoản khi tài khoản mới đăng nhập từ /sign-in) | `method`: `email` / `google` / `apple` |
| 2 | `signup_completed` | Web: tạo tài khoản thành công | `method` |
| 3 | `email_verified` | Web: mở link xác minh thành công | — |
| 4 | `channel_added` | Web: thêm kênh | `auto_record` (true/false) |
| 5 | `auto_record_enabled` | Web: bật tự ghi, lúc thêm kênh hoặc sau đó | `where`: `add_channel` / `channel` |
| 6 | `first_recording_started` | **Server**: bản ghi đầu tiên của tài khoản bắt đầu ghi | `source: server` |
| 7 | `first_recording_ready` | **Server**: bản ghi đầu tiên có video (Ready) | `duration_seconds`, `credits_charged` |
| 8 | `checkout_started` | Web: tạo đơn PayPal | `pack` (tên gói), `package_id`, `credits`, `revenue`, `currency`, `provider` |
| 9 | `purchase_completed` | **Server**: PayPal capture/webhook thành công, mỗi đơn 1 lần | `pack`, `pack_code`, `package_id`, `credits`, `revenue` (USD), `currency`, `first_purchase` |

Pageview (`$pageview`) được ghi tự động theo từng trang, gồm cả trang công khai cho khách chưa đăng
nhập.

Quy tắc chung:

- `distinct_id` là user id nội bộ, gán bằng `identify` khi đăng nhập. Sự kiện phía server cũng dùng
  user id này, nên được gộp vào cùng một người.
- Không gửi email, token, query string hay link ký. Session replay và autocapture đều tắt.
- Không ghi trang `/admin/*`. Tài khoản owner/admin/support/finance bị loại ở cả web (opt-out) và
  server.
- Không ghi khi trình duyệt bật Do Not Track hoặc Global Privacy Control, và không ghi trình duyệt tự
  động (Playwright).

Bước 6, 7 và 9 gửi từ server, nên vẫn được tính khi bản ghi tự động chạy lúc người dùng đã đóng
trình duyệt, hoặc khi thanh toán được xác nhận qua webhook.

## Tạo funnel "Kích hoạt và mua" (một lần)

1. Mở PostHog → **Product analytics** → **+ New insight** → tab **Funnels**.
2. Thêm các bước theo thứ tự: `signup_completed` → `email_verified` → `channel_added` →
   `auto_record_enabled` → `first_recording_started` → `first_recording_ready` →
   `checkout_started` → `purchase_completed`. Có thể thêm `signup_started` làm bước đầu nếu muốn
   xem tỉ lệ bỏ dở form đăng ký.
3. Mục **Conversion window**: 14 ngày.
4. **Breakdown** (tuỳ chọn): Event property `method`, áp dụng cho bước `signup_completed`, để so sánh
   tỉ lệ email, Google và Apple.
5. Đặt tên **Kích hoạt và mua**, bấm **Save**, rồi **Add to dashboard** → tạo dashboard mới
   "SaveStream funnel".

Gợi ý thêm cho dashboard:

- **Trends** cho `purchase_completed`, chọn *Property value sum* của `revenue`: doanh thu theo ngày.
- **Trends** cho `$pageview`, breakdown theo `$pathname`: các trang được xem nhiều nhất.
- Funnel ngắn `checkout_started` → `purchase_completed` (cửa sổ 1 giờ): tỉ lệ hoàn tất thanh toán.

## Lưu ý khi đọc số

- Khi đăng ký bằng email, `signup_started` và `signup_completed` được ghi lúc khách chưa đăng nhập.
  Chúng được gộp vào tài khoản ở lần đăng nhập đầu tiên trên cùng trình duyệt. Nếu người dùng mở
  link xác minh trên máy khác, bước `email_verified` sẽ nằm ở một người ẩn danh khác cho tới khi họ
  đăng nhập trên máy đó.
- Người dùng chặn quảng cáo hoặc bật DNT/GPC sẽ không có sự kiện web. Họ vẫn có các sự kiện server
  (bước 6, 7, 9). Vì vậy funnel đầy đủ có thể thấp hơn thực tế một chút.
- Tuỳ chọn: trong **Project settings** → **IP data capture**, có thể bật *Discard client IP data* nếu
  không cần vị trí gần đúng theo IP.
