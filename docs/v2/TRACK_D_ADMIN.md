# Track D — Trang quản trị (Admin)

Đọc [README.md](README.md), [DECISIONS.md](DECISIONS.md) (mục "Trang quản trị") và [API_CONTRACT.md](API_CONTRACT.md) trước.

**Mục tiêu:** trang quản trị đầy đủ trong web hiện tại, dưới `/admin`, để chủ dịch vụ quản lý người dùng, tiền, bản ghi, cấu hình, an toàn và báo cáo. Track D làm cả backend lẫn web, nhưng **chỉ trong vùng admin**.

**Hiện trạng:** web đã có 4 trang (`/admin/system`, `/admin/workers`, `/admin/jobs`, `/admin/errors`). Backend đã có API cho người dùng, bản ghi, thanh toán, hoàn tiền, cộng trừ credit, nhật ký và số liệu vận hành trong `backend/src/app/api/routes/admin.py` và `operations.py`, với một vai trò `admin` duy nhất (scope `admin:*`).

## Phạm vi file

| Được sửa | Ghi chú |
|---|---|
| `backend/src/app/api/routes/admin*.py`, `backend/src/app/api/schemas/admin*.py` | Tách file mới theo nhóm: `admin_users.py`, `admin_payments.py`, … |
| `backend/src/app/application/admin/**`, `application/audit/**`, `application/operations/**` | |
| `backend/src/app/infrastructure/db/admin_models.py` (file mới) và migration của Track D | |
| `backend/tests/test_v2_d*.py` | |
| `apps/web/src/routes/admin/**`, `apps/web/src/components/admin/**` (thư mục mới), `apps/web/src/repositories/admin-api.ts` (file mới), `apps/web/src/hooks/use-admin-*.ts` | |
| `apps/web/scripts/admin-*.mjs` | Script kiểm tra của phần admin |
| `docs/openapi.yaml` | **Chỉ thêm** đường dẫn `/v1/admin/**` và schema `Admin*` |

**Không sửa:** `apps/mobile/**`, `deploy/**`, và phần không phải admin của backend và web (thuộc Track B). Ngoại lệ được nêu rõ trong từng phase; khi cần chạm file dùng chung, sửa tối thiểu và ghi rõ trong PR.

## Tiến độ

- [ ] D0 — Nền móng: vai trò, xác thực hai lớp, nhật ký, khung giao diện
- [ ] D1 — Người dùng và hỗ trợ khách hàng
- [ ] D2 — Thanh toán, hoàn tiền, giờ cloud
- [ ] D3 — Bản ghi, kênh theo dõi, hàng chờ slot
- [ ] D4 — Cấu hình hệ thống sửa từ giao diện
- [ ] D5 — Gói, giá, khuyến mãi, tặng giờ
- [ ] D6 — Vận hành V2: giao dịch store, ghi trên máy, phần thưởng, thiết bị
- [ ] D7 — Lưu trữ, email, thông báo hàng loạt
- [ ] D8 — Khiếu nại và an toàn
- [ ] D9 — Tổng quan, báo cáo, báo lỗi từ app

## Kiểm tra

Backend (trong `backend`): giống Track B — `ruff check src tests`, `mypy …`, `pytest`, `alembic upgrade head` và `alembic downgrade base`.

Web (ở gốc repo): `npm install`, `npm --workspace apps/web run format`, `npm --workspace apps/web run lint`, `npm run typecheck`, toàn bộ `test:*` trong `.github/workflows/web-ci.yml`, `npm run build`.

CI phải xanh: `Backend CI`, `Backend E2E`, `Web CI`, `Mobile Backend E2E`.

## Quy tắc chung cho mọi phase của Track D

1. **Giao diện admin chỉ có tiếng Anh.** Không thêm chuỗi tiếng Việt, không đưa chuỗi admin vào hệ thống dịch của web.
2. **Quyền theo vai trò ở backend, không chỉ ẩn nút ở web.** Mọi endpoint admin kiểm tra scope. Web ẩn những gì vai trò hiện tại không làm được, nhưng backend là nơi quyết định.
3. **Mọi thao tác thay đổi dữ liệu ghi vào nhật ký** (`application/audit`): ai, lúc nào, làm gì, trên đối tượng nào, giá trị trước và sau, lý do. Thao tác đọc dữ liệu nhạy cảm (xem như người dùng, phát video của người dùng) cũng ghi.
4. **Thao tác nguy hiểm cần xác nhận lại** (cơ chế "step-up" ở D0): hoàn tiền, cộng trừ giờ, đổi vai trò, khoá hoặc xoá tài khoản, xoá bản ghi, đổi cấu hình hệ thống, gửi thông báo hàng loạt, chặn kênh. Người làm nhập lại mật khẩu và ghi lý do.
5. **Không lộ bí mật.** Không endpoint admin nào trả mật khẩu, token, khoá API, hoá đơn store thô hay link tải có chữ ký (trừ luồng phát video có ghi lý do ở D3).
6. **Mọi bảng danh sách** có tìm kiếm, lọc, sắp xếp, phân trang cursor và xuất CSV (xuất ở backend, có giới hạn số dòng, ghi nhật ký).
7. **Tiền và giờ** đi qua `CreditService` và sổ cái hiện có, có khoá idempotency. Không sửa trực tiếp số dư.
8. **Hợp đồng trước:** endpoint mới vào `docs/openapi.yaml` trước khi code, kèm test hợp đồng theo mẫu `backend/tests/test_phase8_admin_api.py`.
9. **Migration:** Track B cũng thêm migration song song. Trước khi merge, rebase lên `main` và sửa `down_revision` để chuỗi migration chỉ có một đầu; `alembic upgrade head` trong CI sẽ fail nếu có hai đầu.
10. **Web:** thành phần mới đặt trong `apps/web/src/components/admin/`, dùng các thành phần `ui/` sẵn có. Không thêm trang admin vào `app-pages.tsx` hay `app-pages-more.tsx`.
11. **Phụ thuộc Track B:** phase nào cần dữ liệu của V2 thì chỉ bắt đầu sau khi phase tương ứng của Track B đã merge (ghi ở đầu phase). Không tự dựng lại phần của Track B.

---

## D0 — Nền móng

**Phụ thuộc:** B1 đã merge (để có khái niệm Free/Pro).

1. **Ba vai trò admin** thay cho một vai trò `admin`, trong `domain/identity/types.py`:
   - `owner`: toàn quyền, gồm cấu hình, phân quyền, thông báo hàng loạt.
   - `support`: người dùng, bản ghi, kênh, khiếu nại; **chỉ xem** thanh toán; không cộng trừ giờ, không hoàn tiền.
   - `finance`: thanh toán, hoàn tiền, cộng trừ giờ, gói, khuyến mãi, báo cáo; chỉ xem người dùng.
   - Scope chi tiết dạng `admin:users:read`, `admin:users:write`, `admin:payments:refund`, `admin:settings:write`, … `owner` có `admin:*`.
   - Migration: tài khoản đang là `admin` chuyển thành `owner`. Giữ `admin` như bí danh của `owner` để token cũ còn chạy.
2. **Xác thực hai lớp (TOTP)** bắt buộc cho mọi vai trò admin: đăng ký bằng mã QR, mã dự phòng dùng một lần, xác minh khi đăng nhập. Tài khoản admin chưa bật thì chỉ vào được trang bật xác thực hai lớp. Khoá TOTP lưu mã hoá. Phần này chạm luồng đăng nhập trong `application/identity` và trang đăng nhập của web: sửa tối thiểu, người dùng thường không bị ảnh hưởng.
3. **Step-up:** endpoint `POST /v1/admin/step-up` nhận mật khẩu (và mã TOTP), trả token ngắn hạn (5 phút); các endpoint nguy hiểm yêu cầu token này và trường `reason`.
4. **Nhật ký:** mở rộng bản ghi audit với `reason`, giá trị trước và sau, địa chỉ IP, vai trò. Trang nhật ký có lọc theo người làm, loại thao tác, đối tượng, khoảng thời gian.
5. **Khung giao diện admin:** bố cục riêng với thanh điều hướng theo nhóm, ô tìm nhanh toàn cục (để trống tới D1), và các thành phần dùng chung: bảng dữ liệu (tìm, lọc, sắp xếp, phân trang, xuất CSV), hộp thoại xác nhận có nhập lý do và step-up, thẻ số liệu, dòng thời gian.
6. **Chuyển 4 trang admin hiện có** ra khỏi `app-pages.tsx` / `app-pages-more.tsx` vào `components/admin/`, giữ nguyên hành vi. Đây là lần duy nhất Track D sửa hai file đó; làm sớm và báo Track B.
7. Trang quản lý admin (chỉ `owner`): danh sách admin, gán và thu hồi vai trò, đặt lại xác thực hai lớp cho người khác.
8. Cập nhật `apps/web/scripts/admin-operations-audit.mjs` cho khớp cấu trúc mới.

---

## D1 — Người dùng và hỗ trợ khách hàng

**Phụ thuộc:** D0.

1. **Danh sách người dùng:** tìm theo email, lọc theo gói (Free/Pro), trạng thái (hoạt động, khoá, chờ xoá), đã xác minh email, ngày đăng ký, nơi mua gần nhất.
2. **Trang chi tiết người dùng** theo thẻ: hồ sơ, gói và số dư giờ, kênh theo dõi, bản ghi, đơn mua, sổ giao dịch, thiết bị, phiên đăng nhập, thông báo đã gửi, ghi chú nội bộ, nhật ký liên quan.
3. Thao tác: khoá và mở khoá, gửi lại email xác minh, buộc đăng xuất mọi thiết bị, buộc đặt lại mật khẩu (gửi email đặt lại), đổi tên hiển thị.
4. **Yêu cầu về dữ liệu cá nhân:** danh sách yêu cầu xoá tài khoản và xuất dữ liệu (dùng `application/privacy` sẵn có), trạng thái, thực hiện hoặc huỷ. Admin xoá tài khoản đi qua đúng luồng xoá hiện có.
5. **Ghi chú nội bộ** theo người dùng: thêm, sửa, ai viết, lúc nào.
6. **Tìm nhanh toàn cục:** một ô nhận email, mã người dùng, mã đơn, mã bản ghi, mã request; trả kết quả theo loại.
7. **Xem như người dùng (chỉ đọc):** endpoint trả dữ liệu mà người dùng đó thấy (entitlement, kênh, bản ghi, số dư) qua các đường dẫn `/v1/admin/users/{id}/view/**`. Không cấp token của người dùng, không thao tác thay. Web hiện dải cảnh báo "Viewing as … (read-only)". Mỗi lần mở ghi nhật ký.

---

## D2 — Thanh toán, hoàn tiền, giờ cloud

**Phụ thuộc:** D0.

1. **Danh sách đơn:** lọc theo trạng thái, nơi mua (web, App Store, Google Play), gói, khoảng thời gian, người dùng. Chi tiết đơn có mã giao dịch của nhà cung cấp và dòng thời gian trạng thái.
2. **Hoàn tiền đơn web** (toàn bộ hoặc một phần) qua API sẵn có; trừ lại số giờ tương ứng, không để số dư âm; hiện trước số giờ sẽ bị trừ.
3. **Đơn mua qua store:** không có nút hoàn; hiện hướng dẫn rằng chỉ Apple và Google hoàn được, và trạng thái tự cập nhật khi store báo về (phần xử lý ở B5).
4. **Đơn kẹt:** danh sách đơn đã thanh toán mà chưa cộng giờ, hoặc ở `pending` quá lâu; nút "đối soát lại" hỏi nhà cung cấp và sửa trạng thái, idempotent.
5. **Sổ giao dịch toàn hệ thống** và theo người dùng; lọc theo loại (mua, tiêu, hoàn, điều chỉnh, tặng).
6. **Cộng trừ giờ thủ công** (API sẵn có): nhập số phút, lý do, và tuỳ chọn "tính như đã mua" (mặc định tắt; xem D5 mục 4 về ảnh hưởng tới Pro).
7. **Khoản giữ bị kẹt:** credit đang giữ cho bản ghi đã kết thúc mà chưa nhả; nút nhả, có kiểm tra bản ghi thật sự đã kết thúc.
8. Xuất CSV đơn và giao dịch theo khoảng thời gian.

---

## D3 — Bản ghi, kênh theo dõi, hàng chờ slot

**Phụ thuộc:** D0. Phần hàng chờ cần **B2** đã merge.

1. **Bản ghi:** mở rộng trang hiện có với lọc theo người dùng, kênh, trạng thái, thời gian; thao tác dừng bản ghi đang chạy, xoá bản ghi (xoá cả file), thử lại.
2. **Gia hạn lưu** cho một bản ghi (đặt `expires_at` mới), có lý do.
3. **Phát hoặc tải video của người dùng:** mặc định trang admin chỉ hiện thông tin bản ghi. Nút "Request playback access" yêu cầu step-up và lý do, tạo link tải ngắn hạn, ghi nhật ký kèm mã bản ghi.
4. **Kênh theo dõi:** danh sách gộp theo kênh (bao nhiêu người theo dõi, bao nhiêu bật tự động ghi), kênh đang lỗi kiểm tra liên tục, kênh tạm dừng và lý do.
5. **Tình trạng bộ dò LIVE:** lần chạy gần nhất, độ trễ, tỉ lệ thất bại theo giờ.
6. **Hàng chờ slot:** các bản ghi đang `waiting_for_cloud_slot` (ai, kênh nào, chờ bao lâu, vị trí), số bản `missed_no_cloud_slot` theo ngày.
7. **Sức chứa:** số luồng ghi đang dùng trên giới hạn toàn hệ thống, biểu đồ theo giờ trong 7 ngày.

---

## D4 — Cấu hình hệ thống sửa từ giao diện

**Phụ thuộc:** D0, và **B1, B4, B6** đã merge (các cấu hình này do Track B tạo dưới dạng biến môi trường).

1. **Bảng cấu hình trong cơ sở dữ liệu** và `RuntimeSettingsService`: giá trị trong DB ghi đè giá trị từ biến môi trường; có bộ đệm ngắn (dưới 30 giây) và làm mới khi đổi, để thay đổi có hiệu lực mà không khởi động lại, kể cả với worker Celery.
2. **Danh sách cấu hình được phép sửa** (khai báo cứng trong code, có kiểu, khoảng giá trị hợp lệ, mô tả):
   - Chế độ bảo trì (bật/tắt, thời gian dự kiến xong).
   - Phiên bản app tối thiểu cho Android và iOS.
   - Số phút dùng thử khi xác minh email.
   - Công tắc Pro ghi trên máy (`unlimited` / `disabled`).
   - Phút Free mỗi ngày, số phần thưởng tối đa mỗi ngày, phút mỗi phần thưởng.
   - Giới hạn kênh theo gói, số luồng cloud mỗi Pro.
   - Thời hạn lưu (đã mua / chưa mua).
   - Bật tắt thanh toán theo kênh: web, App Store, Google Play.
3. **Không bao giờ đưa vào đây:** khoá bí mật, thông tin kết nối cơ sở dữ liệu, Redis, R2, SMTP, nhà cung cấp thanh toán, và số luồng ghi toàn hệ thống (phụ thuộc cấu hình máy chủ, chỉ hiển thị).
4. Các service của Track B đọc cấu hình qua `RuntimeSettingsService` thay cho đọc thẳng `AppSettings`. Đây là thay đổi ngoài vùng admin: sửa đúng các chỗ đọc những cấu hình trên, không đổi hành vi, có test chứng minh giá trị trong DB được dùng.
5. Trang cấu hình (chỉ `owner`): hiện giá trị hiện tại, giá trị mặc định, ai đổi lần cuối; đổi cần step-up và lý do; có nút trả về mặc định.
6. Trang "System" hiện thêm: phiên bản backend đang chạy, thời điểm khởi động, sức khoẻ của API, cơ sở dữ liệu, Redis, R2, SMTP.

---

## D5 — Gói, giá, khuyến mãi, tặng giờ

**Phụ thuộc:** D2.

1. **Gói:** sửa tên, số phút, giá trên web, thứ tự hiển thị, bật tắt bán. Không xoá gói đã có đơn; chỉ ẩn.
2. **Mã sản phẩm store** cho từng gói (App Store, Google Play) và mã biến thể của nhà cung cấp thanh toán web. Khi đổi giá web, hiện nhắc "Update the price in App Store Connect and Google Play Console as well"; giá trong app không sửa được từ đây.
3. **Mã khuyến mãi:** tạo mã cộng một số phút; có hạn dùng, số lượt tối đa, mỗi tài khoản một lần; bật tắt; xem ai đã dùng. Thêm endpoint cho người dùng nhập mã `POST /v1/credits/redeem` (ngoài vùng admin: sửa tối thiểu trong `api/routes/credits.py`, có giới hạn tần suất).
4. **"Tính như đã mua":** giờ tặng, giờ từ mã khuyến mãi và giờ cộng thủ công **không** làm tài khoản thành Pro, trừ khi được đánh dấu "counts as purchase". Bổ sung cờ này vào giao dịch sổ cái và vào quy tắc suy ra gói của B1 (sửa tối thiểu, có test cho cả hai trường hợp).
5. **Tặng giờ hàng loạt:** chọn nhóm người dùng theo bộ lọc của D1, xem trước số người nhận và tổng số phút, step-up, chạy nền, có báo cáo kết quả. Chỉ `owner` và `finance`.

---

## D6 — Vận hành V2

**Phụ thuộc:** D2, và **B3, B4, B5** đã merge.

1. **Giao dịch store:** danh sách và chi tiết giao dịch App Store và Google Play, trạng thái xác minh, thông báo hoàn tiền từ store và số phút đã trừ lại, giao dịch bị từ chối và lý do.
2. **Ghi trên máy:** số phiên theo ngày, phút Free đã cấp và đã dùng, phiên bị đóng tự động; xem phiên của một người dùng.
3. **Phần thưởng quảng cáo:** số lượt hợp lệ, không hợp lệ, đang chờ theo ngày; tài khoản đang bị tạm khoá; mở khoá thủ công (step-up, lý do); danh sách tài khoản có tỉ lệ không hợp lệ cao.
4. **Thiết bị và push:** số thiết bị theo nền tảng và phiên bản app, tỉ lệ gửi push thành công, token bị gỡ; gửi push thử tới một thiết bị của một người dùng.
5. **Phân bố phiên bản app** đang dùng, để quyết định nâng phiên bản tối thiểu.

---

## D7 — Lưu trữ, email, thông báo hàng loạt

**Phụ thuộc:** D0. Thông báo hàng loạt cần **B3** đã merge.

1. **Lưu trữ:** dung lượng đang dùng tổng và theo người dùng (tính từ kích thước artifact trong DB), xu hướng theo ngày; lần chạy gần nhất của tác vụ dọn file hết hạn và số file đã xoá.
2. **File mồ côi:** tác vụ đối chiếu file trên kho lưu trữ với bản ghi trong DB, báo cáo file không có chủ; xoá cần step-up. Chạy theo yêu cầu, có giới hạn để không quét quá tải.
3. **Nhật ký email:** email đã gửi (loại, người nhận, trạng thái, lỗi), giữ 90 ngày; gửi lại một email.
4. **Mẫu email:** sửa tiêu đề và đoạn nội dung chính của từng mẫu, có xem trước và gửi thử tới địa chỉ của admin. Khung HTML vẫn nằm trong `infrastructure/email/templates.py`. Nội dung tuỳ chỉnh lưu trong DB, có nút trả về mặc định. Chỉ `owner`.
5. **Thông báo hàng loạt:** soạn tiêu đề và nội dung, chọn loại:
   - `system` (bảo trì, sự cố): gửi cho mọi người.
   - `marketing`: chỉ gửi cho người đã bật nhận tin khuyến mãi.
   Chọn kênh (trong app, push, email), xem trước số người nhận, step-up, gửi nền có giới hạn tốc độ, báo cáo kết quả. Chỉ `owner`.

---

## D8 — Khiếu nại và an toàn

**Phụ thuộc:** D3.

1. **Hồ sơ khiếu nại** (bản quyền, lạm dụng): tạo thủ công từ email gửi tới `abuse@`, gồm người khiếu nại, kênh hoặc bản ghi bị khiếu nại, nội dung, trạng thái (mới, đang xem xét, đã xử lý, từ chối), người xử lý, dòng thời gian hành động.
2. **Chặn kênh toàn hệ thống:** khi chặn, dừng ngay mọi bản ghi đang chạy của kênh đó; không ai thêm hoặc bật lại được (lỗi `CREATOR_BLOCKED`); các bản ghi đã có của kênh bị **khoá phát và tải**. Thêm kiểm tra danh sách chặn vào chỗ tạo kênh, bộ lập lịch và chỗ tạo link tải (ngoài vùng admin: sửa tối thiểu, có test).
3. Sau khi xem xét, admin chọn: xoá các bản ghi bị khoá, hoặc gỡ chặn và mở lại. **Không tự động hoàn giờ**; hoàn thủ công qua D2 nếu cần.
4. Thông báo trong app cho người dùng bị ảnh hưởng, nội dung trung tính.
5. **Tài khoản đáng ngờ:** danh sách tài khoản bị giới hạn tần suất nhiều lần, đăng ký hàng loạt cùng địa chỉ, hoặc có tỉ lệ phần thưởng không hợp lệ cao.
6. Thêm `CREATOR_BLOCKED` vào `docs/openapi.yaml` và `API_CONTRACT.md` (nhờ Track B xác nhận).

---

## D9 — Tổng quan, báo cáo, báo lỗi từ app

**Phụ thuộc:** D1, D2, D3, D6.

1. **Trang tổng quan** (trang mặc định của `/admin`):
   - Người dùng mới và người dùng hoạt động theo ngày, tuần, tháng.
   - Tỉ lệ Free và Pro; số người chuyển từ Free sang Pro theo tuần.
   - Doanh thu theo ngày và tháng, tách theo web, App Store, Google Play; hiện số trước phí, kèm ghi chú phí store ước tính.
   - Bản ghi đang chạy, đang chờ slot, lỗi trong 24 giờ.
   - Cảnh báo: sức chứa ghi trên 80%, tỉ lệ lỗi bản ghi tăng, đơn kẹt, hồ sơ khiếu nại chưa xử lý.
2. Số liệu tổng hợp tính bằng tác vụ định kỳ và lưu vào bảng tổng hợp theo ngày; trang tổng quan không chạy truy vấn nặng trên bảng gốc.
3. **Báo cáo xuất CSV:** doanh thu theo kỳ, người dùng mới, sử dụng giờ cloud, bản ghi theo trạng thái.
4. **Báo lỗi từ app:** endpoint `POST /v1/support/reports` cho app (màn "Báo lỗi" của thiết kế: mô tả, bản ghi liên quan, log chẩn đoán không chứa video). Thêm vào `docs/openapi.yaml` và `API_CONTRACT.md`. Trang admin: danh sách báo lỗi, trạng thái, gán người xử lý, liên kết tới người dùng và bản ghi. Giữ 180 ngày.
5. Rà toàn bộ quyền theo vai trò bằng một bảng kiểm trong test: mỗi endpoint admin × mỗi vai trò × kết quả mong đợi.
6. Viết `docs/v2/ADMIN_GUIDE.md`: hướng dẫn dùng trang admin cho chủ dịch vụ, bằng tiếng Việt.
