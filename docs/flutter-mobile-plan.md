# SaveStream Flutter Mobile — Implementation Plan

> Handoff / execution plan cho ứng dụng Flutter mobile của SaveStream.
>
> Repo: `ronganminh/SaveStream`
>
> Branch chính cho mobile: `feat/flutter-mobile`
>
> Thư mục ứng dụng: `apps/mobile`
>
> Mục tiêu: xây Flutter app thật theo thiết kế SaveStream đã chốt, hoàn thiện UI bằng mock repository trước, sau đó thay mock bằng backend `/v1` mà không phải viết lại presentation layer.

---

## 1. Phạm vi mobile MVP

Ứng dụng Flutter phải có:

- Onboarding.
- Sign in.
- Register.
- Verify email.
- Forgot/reset password.
- Home dashboard.
- Channels / Watch list.
- Channel detail.
- Add Channel / Watch.
- Recordings list + filter.
- Recording detail.
- Recording lifecycle UI:
  - `queued`
  - `resolving`
  - `waiting_live`
  - `recording`
  - `processing`
  - `uploading`
  - `completed`
  - `failed`
  - `stop_requested`
  - `stopped`
- Usage / Credits.
- Billing / credit packages.
- Settings.
- Profile.
- Language.
- Light / Dark / System theme.
- Bottom navigation.
- Loading / empty / error / retry / skeleton states.
- Mock data để app chạy độc lập.
- Repository abstraction để đổi mock sang API thật.
- Secure mobile session storage.
- SSE / realtime progress và polling fallback.
- VI / EN ngay từ đầu.

---

## 2. Nguyên tắc kiến trúc

### 2.1 Flutter chỉ là API client

Flutter không chứa:

- TikTok resolver.
- Stream recorder.
- FFmpeg.
- Payment verification.
- Credit settlement.
- Final pricing logic.

Flutter chỉ:

```text
render UI
-> gửi command
-> nhận state từ backend
-> hiển thị state
```

Backend là source of truth.

### 2.2 UI không gọi HTTP trực tiếp

Luồng chuẩn:

```text
Screen / Widget
    ↓
Controller / Notifier
    ↓
Repository interface
    ├── MockRepository
    └── ApiRepository
            ↓
         ApiClient
```

Khi backend sẵn sàng:

```text
MockRepository
      ↓
ApiRepository
```

Presentation layer không được rewrite lớn.

### 2.3 Tuân thủ backend contract

Mobile phải map đúng:

- `RecordingStatus`.
- `WatchStatus`.
- `error.code`.
- cursor pagination.
- `actions.can_stop`.
- `actions.can_retry`.
- `actions.can_delete`.
- credit `posted / reserved / available`.
- `Idempotency-Key`.
- SSE sequence / event ID.

Không tự phát minh enum/status khác backend.

---

## 3. Cấu trúc thư mục

```text
apps/mobile/
├── android/
├── ios/
├── assets/
│   ├── branding/
│   ├── icons/
│   └── images/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── bootstrap.dart
│   │   ├── router/
│   │   ├── theme/
│   │   └── localization/
│   ├── core/
│   │   ├── api/
│   │   ├── config/
│   │   ├── errors/
│   │   ├── models/
│   │   ├── storage/
│   │   ├── utils/
│   │   └── widgets/
│   ├── features/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── channels/
│   │   ├── recordings/
│   │   ├── credits/
│   │   ├── billing/
│   │   └── settings/
│   ├── l10n/
│   └── main.dart
├── test/
├── integration_test/
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

Feature lớn dùng cấu trúc:

```text
features/recordings/
├── data/
│   ├── dto/
│   ├── mappers/
│   ├── repositories/
│   └── sources/
├── domain/
│   ├── models/
│   └── repositories/
└── presentation/
    ├── controllers/
    ├── screens/
    └── widgets/
```

Không tạo layer rỗng chỉ để đúng pattern; feature nhỏ được phép đơn giản hóa.

---

## 4. Technical direction

Lựa chọn mặc định:

- Flutter Material 3.
- State management: Riverpod.
- Router: `go_router`.
- Networking: Dio.
- JSON: typed DTO + `json_serializable`.
- Có thể dùng Freezed cho immutable models nếu phù hợp.
- Secure credential storage: `flutter_secure_storage`.
- Localization: Flutter `gen_l10n`.
- Preference local chỉ dùng cho:
  - theme;
  - language;
  - onboarding local flags.
- Không lưu access/refresh token trong plain SharedPreferences.
- API URL theo environment.

Version package được pin khi thực hiện Phase 0 theo Flutter SDK thực tế của repo/CI, không hard-code trong plan.

---

## 5. Design System

Brand chính:

```text
#4F46E5
```

Screen không hard-code màu thương hiệu trực tiếp.

Theme cần semantic token:

```text
primary
primaryContainer
background
surface
surfaceElevated
textPrimary
textSecondary
border
success
warning
error
recording
```

Cần tập trung:

- color;
- typography;
- spacing;
- radius;
- shadow/elevation.

Theme modes:

```text
Light
Dark
System
```

---

## 6. Navigation

Bottom navigation:

```text
Home
Channels
Recordings
Settings
```

Primary action:

```text
Add Channel
```

Routes dự kiến:

```text
/splash
/onboarding

/auth/sign-in
/auth/register
/auth/verify-email
/auth/forgot-password

/home

/channels
/channels/add
/channels/:id

/recordings
/recordings/:id

/credits
/billing

/settings
/settings/profile
/settings/language
/settings/theme
```

Router chịu trách nhiệm:

- auth guard;
- onboarding guard;
- session-expired redirect.

---

# PHASES

## Phase 0 — Flutter Project Bootstrap

### Mục tiêu

Tạo app Flutter chạy thật trong monorepo mà chưa cần feature.

### Tasks

- Tạo `apps/mobile`.
- Khởi tạo Flutter app.
- Set app name SaveStream.
- Chuẩn hóa Android application ID và iOS bundle identifier.
- Cấu hình lint.
- Tạo folder architecture.
- Thêm assets logo/icon từ Brand Kit.
- Tạo environment config:
  - local;
  - staging;
  - production.
- Tạo `bootstrap.dart`.
- Tạo placeholder app.
- Viết `apps/mobile/README.md`.
- Update root `.gitignore` nếu cần cho Flutter.
- Không commit build output.

### CI tối thiểu

```text
flutter pub get
flutter analyze
flutter test
```

### Definition of Done

- `flutter run` boot được app SaveStream.
- Analyzer sạch.
- Tests pass.
- App nằm đúng `apps/mobile`.
- Không ảnh hưởng `apps/api` hoặc `apps/web`.

### Commit

```text
feat(mobile): bootstrap Flutter application
```

---

## Phase 1 — Theme, Design System, Localization

### Mục tiêu

Khóa nền UI trước khi build screen.

### Theme

- Light.
- Dark.
- System.
- Brand colors.
- Typography.
- Spacing.
- Radius.
- Elevation.

### Shared widgets

Tạo:

- `SsPrimaryButton`
- `SsSecondaryButton`
- `SsTextButton`
- `SsIconButton`
- `SsTextField`
- `SsPasswordField`
- `SsCard`
- `SsStatusChip`
- `SsEmptyState`
- `SsErrorState`
- `SsLoadingView`
- `SsSkeleton`
- `SsAvatar`
- `SsListTile`
- `SsSectionHeader`
- `SsConfirmDialog`

### Localization

- Vietnamese.
- English.
- Runtime switch.
- Không hard-code user-facing string trong feature.

### Test

- Light/Dark switching.
- VI/EN switching.
- Widget smoke tests cho component nền.

### Definition of Done

Có internal component/demo screen để kiểm:

- Light.
- Dark.
- VI.
- EN.

### Commit

```text
feat(mobile): add SaveStream design system and localization
```

---

## Phase 2 — Router, App Shell, Mock Foundation

### Mục tiêu

Tạo skeleton đầy đủ để feature cắm vào.

### Tasks

- `MaterialApp.router`.
- Route definitions.
- Auth guard placeholder.
- Onboarding guard.
- Main shell.
- Bottom navigation.
- Preserve tab state.
- Global error handling.
- App lifecycle hooks.
- Mock repository base.
- Mock latency/error helpers.
- Seed mock data.

### Mock scenarios

Mọi feature phải test được:

```text
success
loading
empty
error
offline-like
```

Mock data không được đặt trong screen/widget.

### Definition of Done

Có thể điều hướng 4 tab và detail routes bằng mock.

### Commit

```text
feat(mobile): add routing app shell and mock repository foundation
```

---

## Phase 3 — Auth + Onboarding UI

### Onboarding

- Welcome.
- Auto Recording explanation.
- Private/cloud archive explanation.
- Compliance consent.
- CTA tiếp tục.

Consent copy nên theo hướng:

```text
Only record streams you own, have permission to record,
or are otherwise legally permitted to save.
```

### Sign in

- Email.
- Password.
- Show/hide.
- Forgot password.
- Sign in.
- Register link.

### Register

- Email.
- Password.
- Confirm password.
- Terms acceptance.
- Create account.

### Verify email

- Sent state.
- Resend.
- Cooldown/countdown nếu cần.
- Back/change email.

### Forgot password

- Email.
- Sent state.

### UI states

- Loading.
- Validation.
- Invalid credentials.
- Email not verified.
- Rate limited.
- Generic API error.

### Mock contract

Tạo `AuthRepository` interface:

```text
signIn
register
verifyEmail
resendVerification
forgotPassword
logout
```

### Definition of Done

Toàn bộ auth/onboarding chạy end-to-end bằng mock.

### Commit

```text
feat(mobile): implement onboarding and authentication UI
```

---

## Phase 4 — Home Dashboard

### UI

- SaveStream header.
- Greeting.
- Available credit.
- Active recordings.
- Monitored channels.
- Recent recordings.
- Add Channel CTA.
- Usage summary.
- Low-credit alert.
- Recording-failed alert khi phù hợp.

### States

- Skeleton.
- Empty account.
- No channels.
- No recordings.
- Active recording.
- Low credit.
- Error/retry.

### Architecture

Home widget không tự gọi nhiều repository.

Tạo Home controller/view model để aggregate dữ liệu.

### Definition of Done

Home ổn trên:

- small phone;
- normal phone;
- large phone;
- Light/Dark;
- VI/EN.

### Commit

```text
feat(mobile): implement home dashboard
```

---

## Phase 5 — Channels / Watches

### Mapping domain

```text
Frontend Channel
=
Backend Watch + creator metadata
```

Không tạo domain mobile khác với backend Watch.

### Channel list item

- Avatar.
- Display name.
- @username.
- LIVE / Offline.
- Watch status.
- Auto record.
- Last checked/live.
- Paused/error reason nếu có.

### Add Channel

- Username/source input.
- Validation.
- Optional recording policy nếu contract hỗ trợ.
- Compliance confirmation.
- Submit.

### Channel detail

- Creator info.
- Monitoring status.
- Live status.
- Auto record toggle.
- Latest recording.
- Recording history.
- Pause/resume.
- Delete Watch.

### WatchStatus

Chỉ dùng:

```text
active
paused
paused_insufficient_credit
paused_error
disabled
```

### Definition of Done

UI riêng cho:

- LIVE;
- offline;
- paused;
- insufficient credit;
- error;
- disabled.

### Commit

```text
feat(mobile): implement channels and watch management UI
```

---

## Phase 6 — Recordings UI

### Mục tiêu

Feature quan trọng nhất.

### Recording list

Tabs/filters:

- All.
- Active.
- Completed.
- Failed.

Hỗ trợ:

- Pull to refresh.
- Cursor pagination/load more.
- Empty states.

Card hiển thị:

- creator;
- status;
- start time;
- duration;
- size nếu có;
- cost nếu có;
- artifact/thumbnail state.

### Recording detail theo status

#### queued

Queued indicator.

#### resolving

Resolving source.

#### waiting_live

Waiting state.

#### recording

- Strong recording indicator.
- Elapsed duration.
- Bytes/progress.
- Stop khi `actions.can_stop == true`.

#### processing

Processing/remux state.

#### uploading

Uploading state.

#### completed

- Metadata.
- Playback/download CTA nếu artifact có.
- Actual cost.
- Delete nếu backend cho phép.

#### failed

- Error summary.
- Retry khi `actions.can_retry == true`.

#### stopped

- Stopped metadata.
- Artifact nếu tồn tại.

### Action rule

Không tự suy toàn bộ action từ status.

Ưu tiên backend:

```json
{
  "actions": {
    "can_stop": true,
    "can_retry": false,
    "can_delete": false
  }
}
```

### Definition of Done

Mỗi lifecycle state có UI dễ phân biệt và action đúng.

### Commit

```text
feat(mobile): implement recording list and lifecycle detail UI
```

---

## Phase 7 — Usage, Credits, Billing UI

### Credit

Backend concepts:

```text
posted
reserved
available
```

User-facing UI ưu tiên `available`, nhưng giải thích reserved.

### Usage

- Available balance.
- Reserved balance.
- Recent transactions.
- Recording usage/cost.
- Empty state.

### Billing

- Credit packages.
- Package detail.
- Buy CTA.
- Pending.
- Paid.
- Failed.
- Cancelled/expired.

### Payment rule

Mobile không tự đánh dấu paid sau redirect/deep link.

Phải chờ backend `payment_order.status`.

### Definition of Done

Mock đủ:

- normal;
- low credit;
- no transactions;
- pending checkout;
- paid;
- failed.

### Commit

```text
feat(mobile): implement credits usage and billing UI
```

---

## Phase 8 — Settings + Profile

### Settings

- Profile.
- Theme.
- Language.
- Notifications placeholder nếu chưa có backend.
- Privacy/Terms links.
- Logout.

### Profile

- Email.
- Verification state.
- Backend-supported profile fields.
- Session management entry nếu product bật.

### Theme

```text
Light
Dark
System
```

Persist local.

### Language

```text
Tiếng Việt
English
```

Persist local.

### Account

- Logout.
- Delete-account entry.
- Destructive confirmation.

### Definition of Done

Theme/language apply toàn app và persist qua restart.

### Commit

```text
feat(mobile): implement settings profile theme and language
```

---

# MILESTONE: FULL UI MOCK

Sau Phase 0–8:

- toàn bộ core mobile UI hoàn thành;
- demo được không cần backend;
- backend team có thể tiếp tục độc lập;
- mọi screen dùng repository interface;
- không screen nào phụ thuộc raw HTTP.

---

## Phase 9 — Typed API Client

### Core

Tạo:

- `ApiClient`;
- environment base URL;
- auth header handling;
- request ID extraction;
- typed error parser;
- timeout;
- controlled retry policy.

### Backend error envelope

```json
{
  "error": {
    "code": "INSUFFICIENT_CREDITS",
    "message": "...",
    "request_id": "req_...",
    "retryable": false,
    "details": {}
  }
}
```

Logic branch theo:

```text
error.code
```

Không parse `message`.

### Idempotency

Helper giữ cùng logical key khi retry command:

- create recording;
- create payment order;
- checkout.

Không generate key mới cho mỗi network retry của cùng operation.

### Tests

Fake HTTP responses cho:

- success;
- 401;
- 402;
- 409;
- 429;
- 5xx;
- timeout;
- malformed/error envelope.

### Definition of Done

API layer test được độc lập với UI.

### Commit

```text
feat(mobile): add typed API client and backend error mapping
```

---

## Phase 10 — Real Auth Integration

### Token strategy

```text
access token:
memory

refresh token:
secure storage
```

Không lưu token trong plain preferences.

### Integrate

- register;
- verify email;
- resend;
- login;
- refresh rotation;
- logout;
- forgot/reset flow nếu backend/mobile contract hỗ trợ.

### Refresh

- serialize concurrent refresh;
- tránh nhiều refresh request cùng lúc;
- reuse/session failure -> logout;
- không log token.

### Definition of Done

Restart app có thể restore session qua secure refresh mechanism.

### Commit

```text
feat(mobile): integrate authentication API and secure session storage
```

---

## Phase 11 — Real Channels / Watch API

Endpoints dự kiến:

```text
POST   /v1/watches
GET    /v1/watches
GET    /v1/watches/:id
PATCH  /v1/watches/:id
DELETE /v1/watches/:id
POST   /v1/watches/:id/resume
```

### Requirements

- Typed mapping.
- Cursor pagination nếu áp dụng.
- Mutation rollback khi optimistic UI fail.
- Correct WatchStatus.
- No raw JSON in presentation.

### Definition of Done

Chuyển:

```text
MockWatchRepository
->
ApiWatchRepository
```

mà không rewrite screen.

### Commit

```text
feat(mobile): integrate watch and channel API
```

---

## Phase 12 — Real Recordings + Realtime

### REST

```text
POST /v1/recordings
GET  /v1/recordings
GET  /v1/recordings/:id
POST /v1/recordings/:id/stop
GET  /v1/recordings/:id/artifacts
POST /v1/artifacts/:id/download-url
DELETE /v1/recordings/:id
```

### Realtime

SSE:

```text
GET /v1/recordings/:id/events
```

Client cần:

- Authorization.
- Reconnect.
- Last event ID/sequence.
- Dedupe.
- App background/foreground handling.

Fallback:

```text
GET /v1/recordings/:id
```

với exponential backoff.

### Presigned artifact URL

Không persist URL quá expiry.

Khi expired:

```text
request URL mới
```

### Definition of Done

UI realtime đi được:

```text
queued
-> resolving
-> recording
-> processing
-> uploading
-> completed
```

Stop hoạt động khi server cho phép.

### Commit

```text
feat(mobile): integrate recording API realtime events and artifacts
```

---

## Phase 13 — Real Credits + Billing

Integrate:

```text
GET /v1/credits/balance
GET /v1/credits/transactions
GET /v1/credits/reservations
GET /v1/pricing

GET  /v1/billing/packages
POST /v1/billing/payment-orders
GET  /v1/billing/payment-orders/:id
POST /v1/billing/payment-orders/:id/checkout
```

### Checkout return flow

1. App tạo order.
2. Backend trả checkout URL/deep link.
3. App mở provider.
4. User quay về app.
5. App không tự coi payment là paid.
6. App poll/refetch payment order.
7. Chỉ success khi backend trả `paid`.

### Definition of Done

Credit balance update đúng sau webhook/backend xác nhận payment.

### Commit

```text
feat(mobile): integrate credits and billing API
```

---

## Phase 14 — Async State Polish

Audit mọi async screen:

```text
initial
loading
success
refreshing
empty
recoverable error
non-recoverable error
network/offline-like error
```

### Skeleton

Skeleton phải gần final layout.

Không dùng full-screen spinner cho mọi state.

### Error UX

- Human-friendly.
- Retry khi retryable.
- Request ID trong technical/support detail nếu cần.
- Không show raw exception.

### Commit

```text
refactor(mobile): standardize loading empty and error states
```

---

## Phase 15 — Automated Tests

### Unit

- DTO/domain mapper.
- Error mapping.
- Status mapping.
- Idempotency helper.
- Controllers.
- Session/token behavior.

### Widget

- Auth forms.
- Channel status variants.
- Recording status variants.
- Credit balance.
- Theme/language.
- Loading/error/empty.

### Integration

Critical paths:

```text
launch
-> onboarding
-> login
-> home
```

```text
add channel
-> channel detail
```

```text
active recording
-> stop
-> stopped/completed
```

```text
billing
-> pending
-> paid
```

### Definition of Done

Critical navigation và state flows có automated coverage.

### Commit

```text
test(mobile): add critical unit widget and integration coverage
```

---

## Phase 16 — Accessibility, Responsive, Performance

### Accessibility

- Semantic labels.
- Proper touch targets.
- Text scaling.
- Contrast.
- Screen-reader order.
- Không dùng màu làm signal duy nhất.

### Responsive

Phone-first.

Test:

- small Android;
- normal phone;
- large phone;
- iPhone-like narrow/tall layout.

Tablet polish có thể sau MVP nhưng layout không được vỡ.

### Performance

Audit:

- unnecessary rebuild;
- long lists;
- image caching;
- realtime event frequency;
- pagination memory;
- startup.

### Commit

```text
perf(mobile): improve accessibility responsiveness and performance
```

---

## Phase 17 — Release Readiness

### Flavors/environments

```text
local
staging
production
```

Mỗi môi trường có:

- API base URL;
- environment name;
- release logging policy.

### Android

- Launcher icon.
- Adaptive icon.
- Display name.
- Signing documentation.
- Permissions audit.

### iOS

- App icon.
- Display name.
- Bundle settings.
- Deep link config.
- Permission strings nếu có.

### Security

- No secrets.
- No tokens in logs.
- Secure storage verified.
- Release logging minimized.

### Store/compliance wording

Tránh marketing:

```text
download any creator's livestream
record everything
```

Ưu tiên:

```text
Personal livestream recorder & archive
```

và consent:

```text
Only record streams you own, have permission to record,
or are otherwise legally permitted to save.
```

### Commit

```text
chore(mobile): prepare staging and production release configuration
```

---

# 7. Backend contract dependencies

Flutter UI mock không cần chờ backend.

Real integration cần khóa:

### Auth

- request/response DTO;
- refresh flow;
- error codes.

### Watches

- Watch DTO;
- creator metadata;
- WatchStatus.

### Recordings

- Recording DTO;
- RecordingStatus;
- actions;
- pagination;
- event envelope;
- artifact metadata.

### Credits

```text
posted
reserved
available
```

### Billing

- Package DTO.
- Payment order DTO.
- Checkout response.
- Payment states.

Nếu contract đổi:

```text
DTO
mapper
repository
```

được update.

Presentation không phụ thuộc raw JSON.

---

# 8. Branch Strategy

Branch mobile chính:

```text
feat/flutter-mobile
```

Base:

```text
main
```

## Mặc định

Commit từng phase vào:

```text
feat/flutter-mobile
```

Không đẩy mobile unfinished trực tiếp vào `main`.

Sau milestone ổn định mới mở PR về `main`.

## Nếu cần review cực chi tiết

Có thể tách phase branch:

```text
mobile/phase-0-bootstrap
mobile/phase-1-design-system
...
```

rồi merge về `feat/flutter-mobile`.

Chỉ dùng khi thật sự cần; mặc định một mobile branch là đủ.

---

# 9. Commit Policy

Commit theo functional unit.

Ví dụ:

```text
feat(mobile): bootstrap Flutter application
feat(mobile): add SaveStream design tokens
feat(mobile): implement authentication UI
feat(mobile): implement channels feature
feat(mobile): implement recordings feature
```

Không gom auth + recording + billing + API vào một commit lớn.

Mỗi phase trước khi commit:

- format;
- analyze;
- test;
- kiểm diff;
- không chứa secret/generated junk.

---

# 10. Milestones

## Milestone A — Foundation

Phases:

```text
0–2
```

Kết quả:

- Project chạy.
- Brand/theme.
- VI/EN.
- Router.
- Mock architecture.
- Bottom navigation.

## Milestone B — Full UI MVP

Phases:

```text
3–8
```

Kết quả:

- Gần như toàn bộ app dùng được bằng mock.
- Có thể review UX mà không chờ backend.

## Milestone C — Backend Connected

Phases:

```text
9–13
```

Kết quả:

- Auth thật.
- Watch thật.
- Recording thật.
- Realtime.
- Credits.
- Billing.

## Milestone D — Beta Quality

Phases:

```text
14–17
```

Kết quả:

- States hoàn chỉnh.
- Tests.
- Accessibility.
- Performance.
- Staging/prod.
- Release-ready foundation.

---

# 11. Thứ tự thực hiện

```text
Phase 0  Project bootstrap
   ↓
Phase 1  Design system + Theme + Localization
   ↓
Phase 2  App shell + Router + Mock foundation
   ↓
Phase 3  Auth + Onboarding
   ↓
Phase 4  Home
   ↓
Phase 5  Channels
   ↓
Phase 6  Recordings
   ↓
Phase 7  Credits + Billing
   ↓
Phase 8  Settings

================================
      FULL UI MVP BY MOCK
================================

Phase 9  API client
   ↓
Phase 10 Real Auth
   ↓
Phase 11 Real Channels
   ↓
Phase 12 Real Recordings + SSE
   ↓
Phase 13 Real Credits + Billing
   ↓
Phase 14 Async-state polish
   ↓
Phase 15 Tests
   ↓
Phase 16 Accessibility + Performance
   ↓
Phase 17 Release readiness
```

---

# 12. Definition of Done — UI MVP

UI MVP hoàn thành khi:

- App boot ổn định.
- Onboarding hoàn chỉnh.
- Auth mock hoàn chỉnh.
- Home hoàn chỉnh.
- Channels list/detail/add hoàn chỉnh.
- Recordings đủ mọi lifecycle state.
- Credits/Usage hoàn chỉnh.
- Billing UI hoàn chỉnh.
- Settings/Profile hoàn chỉnh.
- Light/Dark/System hoạt động.
- VI/EN hoạt động.
- Loading/error/empty/skeleton đầy đủ.
- Navigation không dead end.
- Mock repository không nằm trong widget.
- Responsive phone tốt.

---

# 13. Definition of Done — API MVP

User có thể:

```text
register
-> verify
-> login
-> add Watch
-> xem Channel
-> tạo recording
-> xem realtime progress
-> stop recording
-> xem artifact
-> xem credit
-> mua package
-> backend xác nhận paid
-> balance cập nhật
-> logout
```

Nếu SSE mất:

```text
polling fallback vẫn sync state
```

Nếu access token expire:

```text
secure refresh flow hoạt động
```

---

# 14. Những điều không được làm

1. Không gọi HTTP trực tiếp trong widget.
2. Không hard-code mock data trong screen.
3. Không hard-code brand color khắp feature.
4. Không hard-code user-facing text thay vì localization.
5. Không lưu refresh token trong plain SharedPreferences.
6. Không parse backend error message để quyết định logic.
7. Không tự tính final credit cost.
8. Không coi payment redirect là paid.
9. Không tự phát minh Watch/Recording state.
10. Không cache presigned URL quá expiry.
11. Không đưa recording engine/TikTok logic vào Flutter.
12. Không rewrite presentation khi đổi mock sang API.
13. Không merge mobile chưa ổn trực tiếp vào `main`.
14. Không tạo architecture quá nặng cho feature nhỏ.

---

# 15. Quy trình thực hiện mỗi Phase

Khi user yêu cầu:

```text
làm Phase X
```

agent cần:

1. Pull/inspect branch `feat/flutter-mobile`.
2. Đọc plan này.
3. Chỉ làm scope của Phase đó, trừ dependency nhỏ bắt buộc.
4. Không sửa backend trừ khi user yêu cầu.
5. Format code.
6. Run analyzer.
7. Run relevant tests.
8. Review diff.
9. Commit với message rõ ràng.
10. Push lên `feat/flutter-mobile`.
11. Báo:
   - file chính đã tạo/sửa;
   - test/analyzer result;
   - phần còn lại;
   - phase tiếp theo.

Nếu Phase phát hiện backend contract chưa đủ:

- không tự sửa API contract một cách âm thầm;
- ghi rõ dependency/blocker;
- tiếp tục mock UI nếu có thể.

---

# 16. Pull Request milestone

Khi Flutter MVP ổn:

Head:

```text
feat/flutter-mobile
```

Base:

```text
main
```

PR title dự kiến:

```text
feat: add SaveStream Flutter mobile application
```

PR checklist:

- `flutter analyze` pass.
- Tests pass.
- Light/Dark checked.
- VI/EN checked.
- Android build checked.
- iOS config checked khi environment hỗ trợ.
- No secrets/tokens.
- Docs updated.
- API compatibility documented.
- Screenshots cho main flows.

---

# 17. Bước tiếp theo

Bắt đầu bằng:

```text
Phase 0 — Flutter Project Bootstrap
```

Trên:

```text
feat/flutter-mobile
```

Tạo app tại:

```text
apps/mobile
```

Sau Phase 0 phải dừng để:

- kiểm analyzer;
- kiểm test;
- kiểm diff;
- commit;
- push;
- báo kết quả;

rồi mới sang Phase 1.
