# SaveStream Mobile V2 — Quyết định đã chốt

Chốt ngày 03/10/2026. File này ghi lại những chỗ thiết kế V2 lệch với web/backend đang chạy, và cách xử lý đã chốt cho từng chỗ. Khi thiết kế và file này nói khác nhau, **file này đúng**.

Nguồn thiết kế: gói `SaveStream mobile app phase 1.zip` (`docs/SCREENS.md`, `docs/DECISIONS.md`, `docs/BACKLOG.md` và các file `design/*.dc.html`).

## 1. Mô hình sản phẩm

| Hạng mục | Đã chốt |
|---|---|
| Thuê bao | **Không có.** Chỉ bán gói giờ mua một lần, trên cả app và web. |
| Ai là Pro | Tài khoản **có giờ đã mua** là Pro. Còn lại là Free. |
| Free trên mobile | Ghi và lưu video **trên máy người dùng**, 10 phút mỗi ngày, xem quảng cáo thưởng để thêm thời gian. **Không dùng cloud**, để không tốn hạ tầng máy chủ. |
| Free trên web | Được 10 phút cloud dùng thử (10 credit khi xác minh email) để trải nghiệm. Ngoài ra chỉ theo dõi kênh và nhận thông báo. |
| Pro | Tự động ghi trên cloud, không quảng cáo. |
| Màu chính trong app | `#4F46E5` (khớp icon và web), không dùng `#6D49F4` của thiết kế. |

## 2. Giới hạn

| Hạng mục | Free | Pro |
|---|---|---|
| Số kênh theo dõi | 3 | 20 |
| Ghi song song | 1 trên máy (mở ô thứ 2 bằng quảng cáo) | 3 trên cloud |

- Giới hạn 3 kênh của Free áp dụng cả trên web.
- Tài khoản cũ chưa mua nhưng đang có hơn 3 kênh: giữ nguyên các kênh đang có, không cho thêm mới cho tới khi mua giờ.
- **Hàng chờ slot cloud** làm đúng thiết kế: khi Pro đã dùng đủ 3 slot, kênh LIVE tiếp theo chờ theo thứ tự; nếu live kết thúc trước khi tới lượt thì hiện "Bỏ lỡ". Hiện backend chỉ bỏ qua lặng lẽ, cần làm thêm.

## 3. Gói và giá

| Gói | Lượng | Giá |
|---|---|---|
| Starter | 3.000 credit = 50 giờ | $9.99 |
| Standard | 9.000 credit = 150 giờ | $24.99 |
| Premium | 24.000 credit = 400 giờ | $59.99 |

- Ba gói này dùng chung cho web và app. Bộ gói 5 / 20 / 60 giờ trong thiết kế **không dùng**.
- Backend vẫn lưu **credit** (1 credit = 1 phút, làm tròn lên phút). App hiển thị **giờ và phút**. Web ghi thêm "≈ X giờ" cạnh số credit.
- Giờ đã mua không hết hạn.
- Trong app bán qua mua trong app của App Store / Google Play (loại mua một lần, dùng dần). Web bán qua Lemon Squeezy.

## 4. Chỗ theo backend, không theo thiết kế

| Hạng mục | Thiết kế ghi | Đã chốt (theo backend) |
|---|---|---|
| Thời hạn lưu bản ghi cloud | 14 ngày (Pro), 7 ngày | 30 ngày nếu đã mua giờ, 7 ngày nếu chưa |
| Bản ghi cloud bị lỗi | Tính phần đã lưu | Hoàn toàn bộ credit |
| Thứ tự trừ giờ | Thuê bao → phút cũ → Cloud Pack | Chỉ có một số dư duy nhất |

## 5. Màn hình bỏ khỏi V2

- Mọi màn thuê bao: quản lý gói, gia hạn, huỷ, hết hạn/ân hạn, Pro bị thu hồi, "Pro mua trên web" (M11–M14).
- Paywall chọn gói Tháng/Năm (M03): thay bằng một màn chọn gói giờ.
- Các màn "Free + Cloud Pack chọn Local hay Cloud" (Q06): không áp dụng, vì đã mua giờ thì là Pro.

## 6. Làm ở đợt sau

- Đăng nhập Google / Apple: đợt đầu chỉ có email và mật khẩu. Lưu ý Apple yêu cầu có "Sign in with Apple" khi app có đăng nhập Google.
- Đổi mật khẩu trong app: đợt đầu dùng luồng đặt lại qua email.

## 7. Backend cần làm thêm cho V2

- Phân biệt Free/Pro theo việc đã mua giờ, và áp giới hạn kênh theo gói.
- Hàng chờ slot cloud và trạng thái "Bỏ lỡ".
- Tự bật lại tự động ghi sau khi người dùng mua thêm giờ (hiện kênh chỉ chuyển sang "tạm dừng vì hết credit").
- Xác minh hoá đơn App Store / Google Play rồi mới cộng credit.
- Push: đăng ký thiết bị, công tắc "báo khi LIVE" theo từng kênh, các loại thông báo mới (kênh LIVE, sắp hết hạn lưu, sắp hết phút).
- Xác minh quảng cáo thưởng phía server, và đếm phút Free theo ngày.
- Tăng số luồng ghi song song toàn hệ thống (hiện 6) trước khi mở bán, vì mỗi Pro được 3 luồng.

## 8. Việc khác phải làm vì V2

- Cập nhật Terms, Privacy và bảng giá trên web: thêm quảng cáo cho bản Free, mua trong app.
- App mặc định tiếng Anh như web, có đủ bản tiếng Việt theo thiết kế.
- Tên miền trong app là `savestream.online` (thiết kế ghi `savestream.app`).
- Trước khi nộp store: đối chiếu lại quy định hiện hành của Apple và Google về mua trong app, phí, và việc dẫn link ra web để mua.

## 9. Phần đã khớp, không cần xử lý

Giới hạn 20 kênh cho Pro, dừng ghi an toàn khi hết giờ giữa chừng, danh sách thiết bị đã đăng nhập, xoá tài khoản, trường họ tên khi đăng ký.
