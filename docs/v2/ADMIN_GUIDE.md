# SaveStream Admin Guide

Tài liệu này dành cho chủ dịch vụ và nhân sự vận hành SaveStream. Giao diện quản trị thực tế luôn hiển thị **tiếng Anh** theo quyết định sản phẩm; tài liệu hướng dẫn này dùng tiếng Việt.

## 1. Truy cập và bảo mật

Trang quản trị nằm dưới `/admin` trong web SaveStream hiện tại. Mọi tài khoản quản trị phải bật TOTP bằng ứng dụng xác thực. Sau khi đăng nhập, nếu phiên chưa xác minh MFA thì chỉ có thể hoàn tất bước MFA.

Ba vai trò:

- **Owner**: toàn quyền, gồm cấu hình hệ thống, phân quyền admin, email template, broadcast và mọi nghiệp vụ tài chính.
- **Support**: người dùng, bản ghi, kênh theo dõi, khiếu nại, báo lỗi từ app; chỉ đọc thanh toán, không hoàn tiền hay cộng/trừ giờ.
- **Finance**: thanh toán, hoàn tiền, giờ cloud, package/promotion và báo cáo; chỉ đọc dữ liệu người dùng.
- Vai trò `admin` cũ chỉ là bí danh tương thích của Owner.

Các thao tác nguy hiểm yêu cầu **step-up**: nhập lại mật khẩu, mã TOTP và lý do. Token step-up chỉ sống ngắn hạn. Không chia sẻ tài khoản admin.

## 2. Overview

`/admin` và `/admin/overview` là trang tổng quan cho Owner/Finance. Trang này chỉ đọc bảng aggregate theo ngày, không chạy truy vấn nặng trực tiếp trên bảng nghiệp vụ.

Các số chính:

- New users.
- DAU / WAU / MAU.
- Free / Pro hiện tại.
- Free → Pro trong 7 ngày gần nhất.
- Gross revenue USD theo Web, App Store, Google Play.
- Estimated store fee riêng cho App Store/Google Play; đây là **ước tính**, không phải số quyết toán của store.
- Revenue theo tháng hiện tại.
- Recording đang chạy, đang chờ cloud slot, lỗi 24 giờ.
- Cảnh báo khi capacity từ 80%, error rate tăng, có stuck order hoặc complaint chưa xử lý.

Aggregate được Celery cập nhật định kỳ. Nếu số liệu chưa xuất hiện sau deploy mới, kiểm tra worker/beat và task `savestream.admin.d9_rollup`.

## 3. Users

Dùng **Users** để tìm theo email hoặc mã user, lọc theo plan/trạng thái/xác minh email/ngày đăng ký/nơi mua. Trang detail gom profile, entitlement, balance, watches, recordings, payments, ledger, sessions, notifications, notes và audit.

Support có thể hỗ trợ tài khoản nhưng không được thay đổi tiền. Lock/unlock hoặc xóa tài khoản là thao tác nhạy cảm và cần step-up khi UI yêu cầu.

**View as user** chỉ đọc. SaveStream không cấp session/token của người dùng cho admin.

## 4. Payments & cloud minutes

**Payments** dùng cho Owner/Finance; Support chỉ xem.

- Web order có thể refund từ admin.
- App Store / Google Play refund phải thực hiện theo Apple/Google; admin cập nhật theo store event.
- Refund phải trừ credit tương ứng và không làm balance âm.
- **Stuck payments** dùng để tìm order pending quá lâu hoặc paid nhưng chưa grant credit.
- **Ledger** là nguồn kiểm tra mọi thay đổi credit.
- Manual adjustment và bulk grant không biến tài khoản thành Pro trừ khi `counts_as_purchase` được bật rõ ràng.

Revenue trong admin dùng **USD gross trước store fee**. Store fee hiển thị riêng dưới dạng ước tính.

## 5. Recordings, watches và capacity

**Recordings** cho phép lọc theo user/channel/status/time, xem queue và detector health.

Các thao tác có thể gồm stop, retry, retention override và delete. Playback/download video của người dùng không mở mặc định; phải yêu cầu quyền truy cập với reason và audit.

Capacity toàn hệ thống hiện là thông số vận hành read-only. Không sửa giới hạn server từ trang Settings.

## 6. Catalog, promotions và bulk grants

**Catalog** quản lý package name, cloud minutes, web price, thứ tự và trạng thái bán. Giá App Store/Google Play vẫn đổi trong console của từng store.

Promotion code có expiry, max redemptions và one-use-per-account. Bulk grant phải preview audience trước khi chạy.

## 7. System settings

**System** hiển thị health của API, database, Redis, object storage và SMTP. Owner có thể đổi runtime settings nằm trong allowlist.

Secret như JWT key, DB/Redis credentials, R2/SMTP/payment credentials không bao giờ được hiển thị hoặc chỉnh từ admin.

Thay đổi setting nguy hiểm cần step-up + reason và được audit.

## 8. Operations

**Operations** gom storage, email và broadcast.

- Email logs giữ 90 ngày.
- Email template chỉ Owner sửa.
- System broadcast gửi mọi người; marketing broadcast chỉ gửi người đã opt-in.
- Broadcast phải preview audience, step-up và audit.
- Orphan-file delete là thao tác nguy hiểm.

## 9. Safety

**Safety** dành cho Owner/Support.

Complaint case theo dõi copyright/abuse, assignee, status và timeline. Khi block creator toàn hệ thống:

- bản ghi đang chạy bị dừng;
- không thể thêm/bật lại creator;
- recording cũ bị khóa playback/download.

Sau review, admin chọn **Delete recordings** hoặc **Unblock**. Không tự động refund credit; nếu cần hoàn giờ phải xử lý thủ công ở Payments.

Suspicious accounts tổng hợp rate-limit, shared signup IP và reward-abuse signals.

## 10. App reports

**App Reports** dành cho Owner/Support. App gửi report qua `POST /v1/support/reports` với mô tả, recording liên quan và diagnostics.

Diagnostics **không được chứa video/media payload**. Report được giữ tối đa **180 ngày** rồi task D9 xóa tự động.

Admin có thể search, filter, sort, phân trang, CSV export, gán assignee và đổi status. User ID và recording ID có link trực tiếp sang trang admin tương ứng.

## 11. CSV reports

Owner/Finance có bốn report D9:

- Revenue.
- New users / active users / Free-Pro / conversion.
- Cloud usage.
- Recordings by status.

Mặc định export 30 ngày gần nhất; backend giới hạn tối đa 366 ngày cho một lần export. Mỗi export được audit. Revenue CSV dùng USD và tách estimated store fee.

Các danh sách nghiệp vụ khác cũng có export riêng khi được phép.

## 12. Audit và xử lý sự cố

Audit log là lịch sử lâu dài cho thao tác quản trị. Khi điều tra sự cố, ưu tiên:

1. kiểm tra Overview/System health;
2. xem audit theo actor/resource/time;
3. xem queue/recording/payment/support-report liên quan;
4. chỉ dùng thao tác sửa dữ liệu đã có trong admin; không sửa balance hoặc DB trực tiếp.

Nếu CI/deploy vừa thay đổi schema, xác nhận Alembic chỉ có **một head** và worker Celery đang chạy cùng version backend.
