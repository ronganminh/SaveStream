# Media Worker: phương án (chờ chủ sản phẩm chọn)

Trạng thái: **chờ quyết định**. Cập nhật: 2026-10-14.

## Bối cảnh

Bucket R2 `avestream-storage` (chứa toàn bộ bản ghi) nằm ở một tài khoản Cloudflare
**khác** với tài khoản đang giữ zone `savestream.online` và Worker web. Phát video / tải
file hiện đi qua endpoint S3 của R2 và thỉnh thoảng trả lỗi 503. Media Worker đọc R2 qua
binding trực tiếp sẽ hết lỗi này, nhưng binding chỉ dùng được khi Worker nằm **cùng tài
khoản** với bucket.

Không cần gửi token cho ai: mọi secret do chủ sản phẩm tự nhập vào GitHub.

## Phương án 1 — Worker trong tài khoản R2, địa chỉ `*.workers.dev` (đề xuất)

**Chủ sản phẩm làm:**
1. Đăng nhập tài khoản Cloudflare chứa bucket R2 → My Profile → API Tokens → Create Token,
   quyền *Account › Workers Scripts: Edit* và *Account › Workers R2 Storage: Read*, chọn
   đúng tài khoản đó.
2. Copy Account ID của tài khoản đó (trang Overview, cột phải).
3. GitHub repo → Settings → Secrets and variables → Actions → thêm
   `CLOUDFLARE_MEDIA_ACCOUNT_ID` và `CLOUDFLARE_MEDIA_API_TOKEN`.

**Ưu:** ~10 phút; không chuyển dữ liệu, không đổi DNS; hết 503; đảo ngược được (đổi lại
biến môi trường backend).
**Nhược:** link dạng `savestream-media.<tên>.workers.dev`; không có edge cache (Cache API
không chạy trên workers.dev), nhưng binding R2 vẫn nhanh hơn S3.

**Sau đó dev làm:** sửa `deploy-media.yml` dùng 2 secret mới, deploy Worker, rồi đổi biến
môi trường backend bằng drain (có PR để duyệt, không cắt bản ghi đang chạy).

## Phương án 2 — Chuyển zone `savestream.online` sang tài khoản R2

**Chủ sản phẩm làm:** thêm site `savestream.online` vào tài khoản R2 và đổi nameserver ở
nhà đăng ký tên miền (hoặc nhờ Cloudflare "move domain"); chuyển Worker web và tạo lại
token deploy web; cập nhật secret `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_API_TOKEN`.

**Ưu:** có `media.savestream.online` kèm edge cache; mọi thứ chung một tài khoản.
**Nhược:** đổi DNS có thể làm web/API gián đoạn trong lúc nameserver cập nhật (vài phút
đến vài giờ); nhiều việc nhất, rủi ro cao nhất; phải kiểm tra lại DNS, email, SSL.

## Phương án 3 — Bucket R2 mới trong tài khoản web, copy dữ liệu sang

**Chủ sản phẩm làm:** bật R2 và tạo bucket mới trong tài khoản đang giữ
`savestream.online`; tạo R2 API key (Access Key ID + Secret) và đưa vào secret backend;
đồng ý một lần cutover backend bằng drain.

**Ưu:** có `media.savestream.online` kèm edge cache; không động vào DNS.
**Nhược:** phải copy toàn bộ bản ghi (Super Slurper / rclone) và kiểm tra đủ file; tốn gấp
đôi dung lượng trong lúc copy; xoá bucket cũ về sau là việc xoá dữ liệu nên cần chủ sản
phẩm duyệt riêng.

## Đề xuất

Làm **phương án 1** ngay vì nhanh, an toàn, đảo ngược được và đủ sửa lỗi 503. Nếu sau này
muốn tên miền riêng có cache thì làm thêm phương án 3.
