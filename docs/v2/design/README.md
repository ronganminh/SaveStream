# Gói thiết kế SaveStream Mobile V2

Bản sao phần tài liệu của gói thiết kế `SaveStream mobile app phase 1.zip`, để coding agent tra cứu ngay trong repo.

| Đường dẫn | Nội dung |
|---|---|
| `docs/SCREENS.md` | Tra theo ID màn (ví dụ `### W10`): chữ trên màn, nguồn dữ liệu, ghi chú hành vi |
| `docs/BACKLOG.md` | Danh sách toàn bộ màn và biến thể |
| `docs/DECISIONS.md` | Quyết định của **bên thiết kế** theo từng phase |
| `docs/HANDOFF_FULL.md` | Token, component, route, enum của thiết kế |
| `docs/QA.md` | Checklist QA |
| `design/*.dc.html` | File thiết kế; mở bằng trình duyệt, mỗi màn là `<section id="ID">` |
| `reference_code/lib/` | Code Flutter mẫu của bên thiết kế |

## Lưu ý khi dùng

- **`docs/v2/DECISIONS.md` (ở thư mục cha) thắng mọi thứ trong thư mục này.** Gói thiết kế được vẽ cho mô hình thuê bao Pro, Cloud Pack 5 / 20 / 60 giờ, lưu 14 ngày và màu `#6D49F4`; các điểm đó đã bị thay đổi.
- `docs/DECISIONS.md` trong thư mục này là quyết định của bên thiết kế, không phải quyết định sản phẩm cuối cùng.
- `reference_code/` chỉ để xem bố cục. Không chép vào app: nó dùng `ValueNotifier`, chữ tiếng Việt viết cứng, `go_router` phiên bản khác, và không nằm trong bản build hay CI.
