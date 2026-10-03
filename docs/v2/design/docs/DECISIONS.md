# Quyết định đã chốt theo Phase


## Phase 1

SAVESTREAM MOBILE V2 · PHASE 1 Screens gốc · Free / Pro · Light / Dark Foundations + Flutter tokens → Components + App shell → Thiếu spec v1.0 File SaveStream_Mobile_UX_UI_Figma_Design_Spec_VI_v1.0.md chưa có trong project. Phase 1 dựa trên brief + code V1. Mọi quota/giá lấy từ brief; hành vi chưa rõ đánh dấu "?" trong annotation. Quy ước Frame 390×844 (safe area top
- 44 · bottom 34). Icon = Material Symbols Rounded (map trực tiếp sang Flutter Icons.*_rounded). Copy VI. Mỗi màn: Light, Dark, annotation. H01/W01/L01 thêm QA 360×800 + 430×932 (Light). Nội dung dưới fold là vùng cuộn.

## Phase 1

Quyết định đã chốt (vòng 1)
- 1 · Phút Free reset 00:00 UTC (backend). UI: "Reset sau X giờ Y phút".
- 2 · Trừ: subscription 30 h → legacy → Cloud Pack. Pack không hết hạn.
- 3 · Recording bar mọi tab (compact trên Home). Ẩn chỉ ở Active Recording detail.
- 4 · "Thông báo khi LIVE" theo creator, default ON, chỉ tắt push.
- 5 · FAILED cloud chỉ tính phần đã lưu. "Thử lại" khi còn LIVE + retryable.
- 6 · Retention: Free + Cloud Pack 7 ngày · Pro 14 ngày. Ghi rõ trước khi mua.
- 7 · UNKNOWN dùng next_check_at; thiếu → "SaveStream sẽ tự kiểm tra lại".
- 8 · Không có picker chất lượng Local. Chỉ thông tin "Tự động / theo nguồn".
- 9 · Tab localize. VI: Trang chủ / Theo dõi / Bản ghi / Cài đặt.
- 10 · Hết phút ngày: 1 Rewarded Ad → 10 phút cho recording mới, không bank, tính cap 8.
- 11 · Local sync metadata giữa device; file chỉ ở máy đã record → "Không có trên máy này".

## Phase 2

Quyết định đã chốt (vòng 2)
- 1 · Không checkbox quyền record; 1 dòng helper + Terms chung.
- 2 · PAUSED vẫn chiếm slot 3/20. Lấy lại slot = Xoá.
- 3 · Đủ 3 cloud → WAITING_FOR_CLOUD_SLOT (FIFO) → RECORDING hoặc MISSED.
- 4 · Không trial subscription. Cloud trial 10 phút trên Web ≠ Pro trial.
- 5 · Email/password bắt buộc verify (A04 → A06-verify → A07).
- 6 · NOT_FOUND (W07) · PRIVATE/RESTRICTED (W08) · UNAVAILABLE khi không chắc.
- 7 · Local từ máy khác: read-only, không Delete. Chỉ máy nguồn xoá được.

## Phase 3

Quyết định đã chốt (Phase 3)
- 1 · Pool 10 phút/ngày dùng chung; 2 recording = trừ gấp đôi. Reward gắn với recording nhận nó.
- 2 · Slot #2 hết hạn không dừng recording đang chạy; chỉ chặn recording thứ 2 mới.
- 3 · Không trừ phút khi RECONNECTING không ghi media. Usage = duration media đã lưu.
- 4 · R01 chỉ lần đầu hoặc khi cần xác nhận. Bình thường một chạm.
- 5 · Stop trên notification Android → dừng ngay + finalize, không mở app.
- 6 · SSV chậm: chờ ~15 giây → banner chờ; tới muộn → cộng hoặc credit 24 giờ; invalid → không cộng.
- 7 · LOW
- 8 · iOS giữ màn hình sáng (isIdleTimerDisabled) chỉ khi đang ghi foreground.
- 9 · Cap 8/ngày chỉ đếm reward VALID. INVALID +0 (invalid_attempts +1). PENDING chưa tăng gì.

## Phase 4

Quyết định đã chốt (Phase 4) ID theo inventory L01–L14 · đã đủ (L02 trống, L03 tìm kiếm, L11 đang xử lý).
- 6 · L13 xoá theo ngữ cảnh: Local / Cloud / cả hai; nút ghi rõ thứ bị xoá.
- 1 · "Tải về thiết bị" ở L07. Bản local dùng được sau khi cloud hết hạn.
- 2 · Cảnh báo từ 3 ngày trước; push 1 lần ở ~24 giờ trước.
- 3 · Share Cloud = tải file tạm → native share sheet. Không public link V1.
- 4 · Cloud hết hạn hiện thêm 7 ngày (EXPIRED), sau đó ẩn khỏi Library mặc định.
- 5 · Player: portrait + landscape full-screen + auto-rotate. Không PiP V1.

## Phase 5

Quyết định (Phase 5)
- 1 · Pro $4.99/tháng · $39.99/năm. Tiết kiệm 33% tính runtime từ giá store.
- 2 · Paywall full-screen, 5 context: Auto-record, Watch List đầy, iOS chạy nền, Hết phút Free, Bỏ quảng cáo. Chỉ đổi headline + copy phụ. Không banner ad.
- 3 · User huỷ ≠ thất bại: huỷ không báo lỗi; thất bại có banner + thử lại; pending không cấp Pro.
- 4 · Entitlement chỉ cấp sau khi backend verify.
- 5 · Cloud Pack = giờ cloud mua một lần, không phải Pro. Lưu 7 ngày. Baseline $1.99 / $5.99 / $12.99, giá hiển thị từ storefront.
- 6 · Huỷ / đổi gói qua trang subscriptions native. Pro mua trên web: "Quản lý trên web", không mua lại.

## Phase 6

Quyết định (Phase 6)
- 1 · Đăng xuất khi đang record Local: bắt buộc dừng + lưu xong mới revoke token. Cloud job không dừng.
- 2 · Xoá tài khoản 2 bước: hậu quả + cảnh báo subscription store → re-auth + tick xác nhận.
- 3 · Session hết hạn khi record Local: recorder chạy tiếp bằng lease phút đã cấp, không redirect, không xoá segment.
- 4 · File Local gắn user ID, giữ sau đăng xuất, chỉ hiện lại với đúng tài khoản.
- 5 · Offline: dữ liệu cache + giờ cập nhật; hành động cần mạng disabled kèm lý do, không ẩn.
- 6 · Xin quyền push ở A09 (onboarding). Bỏ qua → hỏi lại 1 lần ở N03 sau khi thêm creator đầu tiên.

## Phase 8

Quyết định (Phase 8)
- 1 · CLOUD_QUOTA_EXHAUSTED: auto-record → PAUSED_NO_CLOUD_MINUTES, 1 push, CTA Mua Cloud Pack. Mua xong bật lại cho LIVE tiếp theo, không backfill.
- 2 · CLOUD_PACK_DEPLETED_DURING_RECORDING: dừng an toàn + finalize, không âm balance, không giả vờ tiếp tục.
- 3 · Free + pack: sheet chọn Local (mặc định) / Cloud (ghi rõ trừ pack). Không pack → đi thẳng Local.
- 4 · Đặt mật khẩu (social) chỉ khi backend hỗ trợ credential đó.
- 5 · Trùng email: không tạo account trùng; xác minh bằng mật khẩu hoặc mã email rồi liên kết.
- 6 · Bản Local của account khác: cảnh báo, không import, không đổi owner.
- 7 · Consent: state machine; ATT chỉ khi needsTracking, UMP theo khu vực; không cần thì skip.
- 8 · PRO_REVOKED: mất ngay, không grace; Cloud theo entitlement còn lại; Local giữ nguyên.
