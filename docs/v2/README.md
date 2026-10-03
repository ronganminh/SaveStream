# SaveStream V2 — Kế hoạch triển khai theo track

Bộ tài liệu này để giao cho một coding agent (ChatGPT/Codex hoặc tương đương) làm song song 3 track. Mỗi track là một file riêng, chia thành các phase. **Mỗi phase = một nhánh = một PR = CI xanh = merge vào `main`.**

| File | Nội dung |
|---|---|
| [DECISIONS.md](DECISIONS.md) | Quyết định sản phẩm đã chốt. Khi thiết kế và file này khác nhau, file này đúng. |
| [API_CONTRACT.md](API_CONTRACT.md) | Hợp đồng API mới của V2. Cả 3 track code theo file này. |
| [TRACK_A_MOBILE_UI.md](TRACK_A_MOBILE_UI.md) | Track A: giao diện app Flutter, dữ liệu giả trước. |
| [TRACK_B_BACKEND_WEB.md](TRACK_B_BACKEND_WEB.md) | Track B: backend FastAPI và web. |
| [TRACK_C_MOBILE_NATIVE.md](TRACK_C_MOBILE_NATIVE.md) | Track C: phần native của app (ghi trên máy, mua trong app, quảng cáo, push) và nối API thật. |

## Cách dùng

1. Mở 3 phiên agent riêng, mỗi phiên một track.
2. Đưa cho mỗi phiên: file `README.md` này, `DECISIONS.md`, `API_CONTRACT.md`, file track của nó, và gói thiết kế `SaveStream mobile app phase 1.zip`.
3. Ra lệnh: "Làm phase tiếp theo chưa đánh dấu xong trong file track, theo đúng quy trình trong README."
4. Sau mỗi phase, agent báo lại theo mẫu ở mục "Báo cáo sau mỗi phase".

Không cần repo mới. Tất cả làm trên repo `ronganminh/SaveStream`, nhánh gốc là `main`.

## Bản đồ repo

| Đường dẫn | Là gì | CI |
|---|---|---|
| `apps/mobile/` | App Flutter (Riverpod, go_router, Dio) | `Mobile CI`, `Mobile Backend E2E` |
| `backend/` | FastAPI + Celery, SQLAlchemy, Alembic | `Backend CI`, `Backend E2E` |
| `apps/web/` | Web TanStack Start trên Cloudflare Workers | `Web CI` |
| `docs/openapi.yaml` | Hợp đồng API đóng băng, có test đối chiếu | `Backend CI` |
| `deploy/` | Cấu hình production | **Không đụng** |

## Quy trình cho mỗi phase

```bash
git switch main && git pull --ff-only
git switch -c v2/<track>-<số>-<tên-ngắn>      # ví dụ: v2/a1-auth-onboarding
# ... code và test trên máy theo lệnh "Kiểm tra" của track ...
git add <các file của phase> && git commit -m "feat(mobile): ..."
git push -u origin HEAD
gh pr create --base main --title "..." --body "..."
gh pr checks --watch          # đợi CI
gh pr merge --merge           # chỉ khi mọi check đều xanh
git switch main && git pull --ff-only
```

Quy tắc bắt buộc:

1. **Một phase một PR.** Không gộp nhiều phase, không làm dở phase này rồi nhảy sang phase khác.
2. **Chỉ merge khi CI xanh toàn bộ.** CI đỏ thì sửa trên cùng nhánh rồi đẩy lại. Không tắt, không bỏ qua, không sửa test cho qua mà không hiểu vì sao nó fail.
3. **Trước khi merge, rebase lên `main` mới nhất** (`git fetch origin && git rebase origin/main`), chạy lại kiểm tra, rồi mới merge. Track khác có thể vừa merge.
4. **Dùng merge commit** (`--merge`), giống lịch sử hiện tại của repo.
5. **Sau khi merge, đánh dấu `[x]` cho phase đó** trong file track của mình (commit kèm trong chính PR đó, trước khi merge). Không sửa file track của track khác.
6. **Không deploy.** Không chạy lệnh nào lên VPS hay Cloudflare. Chủ repo tự deploy.
7. **Không đụng secret, `deploy/`, DNS, hay dữ liệu production.**
8. **Không thêm tính năng ngoài phạm vi phase.** Thấy thiếu thì ghi vào mục "Ghi chú" của PR.

## Quyền sở hữu file (để 3 track không đạp nhau)

| Đường dẫn | Track được sửa |
|---|---|
| `apps/mobile/lib/features/**/presentation/**`, `apps/mobile/lib/core/widgets/**`, `apps/mobile/lib/app/router/**`, `apps/mobile/lib/app/theme/**` | A |
| `apps/mobile/lib/l10n/*.arb` | **Chỉ A** |
| `apps/mobile/lib/features/**/domain/**` và `**/data/repositories/mock_*` | A |
| `apps/mobile/lib/features/**/data/remote/**` và `**/data/repositories/api_*` | C |
| `apps/mobile/lib/platform/contracts/**`, `apps/mobile/lib/platform/fakes/**` | A |
| `apps/mobile/lib/platform/**` (phần còn lại), `apps/mobile/android/**`, `apps/mobile/ios/**` | C |
| `apps/mobile/pubspec.yaml`, `apps/mobile/pubspec.lock` | **Chỉ C** |
| `apps/mobile/lib/app/bootstrap.dart` | C |
| `apps/mobile/lib/app/savestream_app.dart` | A (chỉ ở phase A0), sau đó không ai sửa |
| `apps/mobile/test/**` | A và C, mỗi track tạo file test riêng có tiền tố `v2a_` hoặc `v2c_` |
| `backend/**`, `docs/openapi.yaml`, `docs/api/**`, `apps/web/**` | B |
| `.github/workflows/mobile-*.yml`, `apps/mobile/tool/**` | C |
| `.github/workflows/backend-*.yml`, `.github/workflows/web-ci.yml` | B |
| `docs/v2/API_CONTRACT.md` | B (A và C muốn đổi thì mở issue hoặc ghi vào PR, không tự sửa) |
| `docs/v2/DECISIONS.md` | Chỉ chủ repo |

Nếu một phase bắt buộc phải sửa file của track khác, dừng lại và báo, không tự sửa.

Chuỗi hiển thị (ARB) là điểm dễ xung đột nhất. Track C cần chuỗi mới thì dùng các key Track A đã tạo sẵn ở phase A0 (mục "Chuỗi cho phần native"); thiếu key thì báo để Track A thêm.

## Thứ tự và phụ thuộc giữa các track

```text
A0 ──► A1 ► A2 ► A3 ► A4 ► A5 ► A6 ► A7
 │
 └──► C0 ► C1 ► C2(spike, dừng chờ duyệt) ► C3 ► C4 ► C5 ► C6 ► C7 ► C8 ► C9
B0 ──► B1 ► B2 ► B3 ► B4 ► B5 ► B6 ► B7 ► B8
```

- **A0 phải merge trước** khi C0 bắt đầu (C dùng interface và điểm nối do A0 tạo).
- **B0 phải merge trước** khi C1 bắt đầu (C1 code theo hợp đồng trong `docs/openapi.yaml`).
- A và B chạy song song từ đầu, không phụ thuộc nhau.
- Phụ thuộc chi tiết theo từng phase ghi ở đầu mỗi phase.

## Nguồn thiết kế

Gói `SaveStream mobile app phase 1.zip` (chủ repo cung cấp), thư mục `flutter_export/`:

- `docs/SCREENS.md`: tra theo ID màn (ví dụ `### W10`): chữ trên màn, nguồn dữ liệu, ghi chú hành vi.
- `docs/BACKLOG.md`: danh sách toàn bộ màn.
- `docs/DECISIONS.md` và `docs/HANDOFF_FULL.md`: quy tắc và token của thiết kế.
- `design/*.dc.html`: mở bằng trình duyệt để xem bố cục; mỗi màn là `<section id="ID">`.
- `lib/`: code mẫu của bên thiết kế. **Chỉ tham khảo bố cục.** Không chép nguyên vào app: nó dùng `ValueNotifier`, chữ tiếng Việt viết cứng, và mô hình thuê bao đã bị bỏ.

Thứ tự ưu tiên khi có mâu thuẫn: `docs/v2/DECISIONS.md` > `docs/v2/API_CONTRACT.md` > `SCREENS.md` của thiết kế > code mẫu của thiết kế.

## Quy ước code

- Theo đúng kiểu code đang có trong từng thư mục: đặt tên, mật độ comment, cấu trúc feature-first.
- Flutter: không viết cứng màu hay cỡ chữ; dùng `Theme.of(context).colorScheme`, `textTheme`, `SsSpacing`, `SsRadii`, `context.semanticColors`. Dùng widget trong `lib/core/widgets/` trước khi tạo mới. Mọi chữ hiển thị đi qua ARB (EN và VI), mặc định tiếng Anh.
- Màu chính là `#4F46E5`. Không đổi theme theo màu của gói thiết kế.
- Backend: mọi endpoint mới phải có trong `docs/openapi.yaml` trước; có migration Alembic chạy được `upgrade head` và `downgrade base`.
- Commit theo dạng `feat(mobile): ...`, `fix(backend): ...`, `docs(v2): ...`.

## Báo cáo sau mỗi phase

```text
Phase: <mã và tên>
PR: <link> — trạng thái: merged / đang chờ / bị chặn
CI: <tên check>: pass/fail
Đã làm: <3–6 gạch đầu dòng>
Chưa làm / lệch so với mô tả phase: <nếu có, kèm lý do>
Cần chủ repo quyết định: <nếu có>
```

## Khi nào phải dừng và hỏi chủ repo

- Phase ghi rõ "dừng chờ duyệt".
- Cần tài khoản hoặc khoá bên ngoài (Apple Developer, Google Play, AdMob, Firebase).
- Cần đổi `DECISIONS.md`, hoặc thiết kế và quyết định mâu thuẫn mà hai file không giải quyết được.
- Cần sửa file thuộc track khác.
- CI đỏ vì lý do nằm ngoài phase (hạ tầng, hết phút Actions).
