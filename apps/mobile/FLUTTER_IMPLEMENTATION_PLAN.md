# SaveStream Mobile — Flutter Implementation Plan

> Handoff document for phased implementation of the SaveStream Flutter application.
>
> Repository: ronganminh/SaveStream  
> Target directory: apps/mobile  
> Platforms: Android + iOS  
> Development model: UI-first with typed mock repositories, then switch feature-by-feature to the real SaveStream API.

---

# 1. Purpose

Build a real Flutter mobile application for SaveStream based on the approved SaveStream mobile design and the existing web product structure.

The mobile app must be able to progress independently while the backend is being migrated from the existing working CLI recorder to the API architecture.

The Flutter app is a client only.

It must NOT:

- contain TikTok recording logic;
- call TikTok directly;
- embed backend secrets;
- calculate authoritative recording charges;
- decide payment success itself;
- own recording orchestration;
- duplicate backend state-machine rules.

All recording, watch, pricing, credit, billing, storage and authorization decisions come from the backend API.

---

# 2. Product scope

The Flutter app will include:

- real Flutter project, not a static mockup;
- Android and iOS targets;
- SaveStream Brand Kit;
- Light / Dark / System theme;
- Vietnamese and English localization;
- authentication flows;
- onboarding;
- Home dashboard;
- Channels / Watch management;
- Channel detail;
- Add Channel;
- Recordings list;
- recording filters;
- Recording detail;
- active recording state;
- processing state;
- ready/completed state;
- failed/stopped states;
- Usage & Credits;
- Billing UI;
- Profile;
- Settings;
- Language;
- Theme;
- bottom navigation;
- loading states;
- skeleton states;
- empty states;
- error states;
- typed mock repositories;
- repository/service boundaries suitable for real API integration;
- API error-code mapping;
- cursor pagination;
- Idempotency-Key support;
- recording actions from backend;
- credit balance display;
- SSE/realtime progress with polling fallback after backend integration.

---

# 3. Repository placement

The repository already uses:

~~~text
apps/api
apps/web
~~~

The Flutter application belongs at:

~~~text
apps/mobile
~~~

Do not create another root-level Flutter repository.

Expected high-level monorepo structure:

~~~text
SaveStream/
├── apps/
│   ├── api/
│   ├── web/
│   └── mobile/
├── docs/
├── services/
├── packages/
└── infra/
~~~

The mobile app owns only code under:

~~~text
apps/mobile/
~~~

unless a later explicit phase adds shared generated API contracts under a common package.

---

# 4. Architectural principles

## 4.1 Feature-first structure

Use a feature-first architecture.

Expected structure:

~~~text
apps/mobile/
├── android/
├── ios/
├── assets/
│   ├── brand/
│   ├── icons/
│   └── illustrations/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── bootstrap.dart
│   │   ├── router/
│   │   ├── theme/
│   │   └── localization/
│   │
│   ├── core/
│   │   ├── api/
│   │   ├── config/
│   │   ├── errors/
│   │   ├── models/
│   │   ├── storage/
│   │   ├── widgets/
│   │   └── utils/
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── channels/
│   │   ├── recordings/
│   │   ├── credits/
│   │   ├── billing/
│   │   └── settings/
│   │
│   └── main.dart
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── golden/
│
├── integration_test/
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
~~~

Each feature should normally contain only the layers it needs:

~~~text
feature/
├── data/
│   ├── dto/
│   ├── repositories/
│   └── sources/
├── domain/
│   ├── models/
│   └── repositories/
├── presentation/
│   ├── controllers/
│   ├── screens/
│   └── widgets/
└── feature.dart
~~~

Do not create empty architecture folders only to imitate Clean Architecture.

Create layers when there is actual code belonging to them.

---

# 5. Locked Flutter technology choices

Unless a later phase explicitly changes them, use:

- Flutter stable;
- Dart stable compatible with the chosen Flutter SDK;
- Material 3;
- Riverpod for application state;
- go_router for navigation;
- Dio for HTTP transport;
- flutter_secure_storage for mobile refresh-token storage;
- shared_preferences only for non-sensitive local preferences such as theme/language/onboarding;
- Flutter localization / ARB for i18n;
- flutter_test for unit/widget testing;
- integration_test for integration flows.

Optional dependencies must be justified before addition.

Avoid introducing:

- multiple state-management frameworks;
- multiple routing frameworks;
- multiple HTTP clients;
- a second dependency-injection framework unless clearly necessary.

---

# 6. State-management rule

Use Riverpod consistently.

Recommended layers:

~~~text
Screen
  ↓
Controller / Notifier
  ↓
Repository interface
  ↓
Mock repository OR API repository
~~~

Example:

~~~text
ChannelsScreen
      ↓
ChannelsController
      ↓
WatchRepository
      ├── MockWatchRepository
      └── ApiWatchRepository
~~~

Presentation widgets must not know whether the repository is mock or real.

The switch between mock and real API must happen through provider/configuration wiring.

---

# 7. Mock-first strategy

Until the corresponding backend endpoint is stable:

~~~text
UI
 ↓
domain repository interface
 ↓
mock repository
~~~

After backend implementation:

~~~text
UI
 ↓
same domain repository interface
 ↓
API repository
~~~

The UI should not be rewritten during that switch.

Mock data must simulate:

- loading;
- normal result;
- empty result;
- failure;
- pagination;
- recording progress;
- processing;
- failed recording;
- insufficient credit;
- offline creator;
- active live creator.

Mocks should use the same domain values expected from the API contract.

---

# 8. Backend contract alignment

The Flutter app follows the SaveStream backend handoff contract.

Canonical recording statuses:

~~~text
queued
resolving
waiting_live
recording
processing
uploading
completed
failed
stop_requested
stopped
~~~

Canonical Watch statuses:

~~~text
active
paused
paused_insufficient_credit
paused_error
disabled
~~~

Do not invent alternate enums in Flutter.

---

# 9. Product-status mapping

Backend status and user-facing status are not always identical.

Use a presentation mapper.

Suggested UI mapping:

| API status | Mobile label |
|---|---|
| queued | Waiting |
| resolving | Preparing |
| waiting_live | Waiting for live |
| recording | Recording |
| processing | Processing |
| uploading | Processing |
| completed | Ready |
| failed | Failed |
| stop_requested | Stopping |
| stopped | Stopped |

Vietnamese labels belong in localization resources, not in the mapper.

The mapper should return a semantic presentation state, not hard-coded localized strings.

---

# 10. Watch vs Channel terminology

Backend resource:

~~~text
Watch
~~~

Product UI:

~~~text
Channel
~~~

Mapping:

~~~text
Channel UI
=
Watch resource
+
resolved creator metadata
~~~

Do not create an unrelated mobile-only Channel backend model.

Domain model may be named:

~~~text
Watch
~~~

or:

~~~text
ChannelWatch
~~~

but API serialization must continue to match the backend Watch contract.

---

# 11. Core API rules

When API integration begins:

- branch on machine-readable error.code;
- never parse API error message to drive logic;
- support cursor pagination;
- generate Idempotency-Key for required mutations;
- never calculate authoritative price locally;
- use backend actions.can_stop / can_retry / can_delete;
- use backend credit posted/reserved/available;
- treat payment redirect/deep link only as UI navigation;
- confirm payment status with backend;
- do not persist presigned download URLs past expiry;
- do not log tokens;
- do not log sensitive request bodies.

---

# 12. Authentication rules

## Access token

Keep access token in memory where practical.

## Refresh token

On Android/iOS store refresh token only in secure storage.

Do not use SharedPreferences for auth secrets.

## Refresh behavior

API client should eventually support:

~~~text
401
 ↓
single refresh attempt
 ↓
rotate refresh token
 ↓
retry original request
~~~

Prevent multiple simultaneous requests from triggering multiple refresh rotations.

Use a refresh mutex/single-flight mechanism when the real API is integrated.

---

# 13. Navigation map

Public routes:

~~~text
/splash
/welcome
/sign-in
/register
/forgot-password
/verify-email
~~~

Onboarding:

~~~text
/onboarding
~~~

Authenticated shell:

~~~text
/home
/channels
/recordings
/settings
~~~

Nested routes:

~~~text
/channels/add
/channels/:watchId

/recordings/:recordingId

/credits
/billing
/billing/packages

/settings/profile
/settings/language
/settings/theme
~~~

Route names should be centralized.

Do not hard-code route strings throughout widgets.

---

# 14. Bottom navigation

Main tabs:

~~~text
Home
Channels
Recordings
Settings
~~~

The Add Channel action is visually prominent but does not need to become an extra permanent navigation tab.

Use a shell route so tab state remains stable when switching tabs.

---

# 15. Screen inventory

The final mobile app should cover at least these screens/states.

## Entry and Auth

1. Splash
2. Welcome
3. Sign in
4. Register
5. Forgot password
6. Verify email
7. Reset-password result/error states

## Onboarding

8. Intro
9. How SaveStream works
10. Recording/content permission acknowledgement
11. Finish onboarding

## Home

12. Home dashboard
13. active recording card
14. watched channels summary
15. storage/usage/credit summary
16. recent recordings
17. zero-data home state

## Channels

18. Channels list
19. live channel state
20. offline channel state
21. paused channel state
22. insufficient-credit paused state
23. Channels empty state
24. Add Channel
25. Channel detail
26. pause/resume watch
27. delete/remove confirmation

## Recordings

28. Recordings list
29. filter/sort sheet
30. Waiting state
31. Recording state
32. Processing state
33. Ready state
34. Failed state
35. Stopped state
36. Recording detail
37. download action
38. delete confirmation

## Credits / Usage / Billing

39. credit balance
40. reserved credit explanation
41. transaction history
42. packages
43. checkout pending
44. payment success
45. payment failed
46. payment still pending

## Settings

47. Settings
48. Profile
49. Language
50. Theme
51. Sessions/devices when backend supports it
52. Sign out confirmation
53. Account deletion entry when backend supports it

---

# 16. Shared UI states

Every major feature must support the following patterns.

## Loading

- initial loader;
- skeleton where appropriate;
- pagination loader.

## Empty

Explain what the user can do next.

Examples:

- no channels → Add your first channel;
- no recordings → recordings will appear here;
- no transactions → no credit activity yet.

## Error

Must include:

- user-readable message;
- retry action when retryable;
- no raw stack traces;
- no raw backend message required for logic.

## Offline / connectivity

Do not pretend destructive operations succeeded while offline.

For read-only cached data, later phases may show stale content with a visible stale/offline indication.

---

# 17. Design-system rules

Use SaveStream Brand Kit as source of truth.

Primary brand color currently used by SaveStream:

~~~text
#4F46E5
~~~

Do not scatter raw color literals throughout screens.

Create semantic theme tokens.

Example semantic groups:

~~~text
primary
onPrimary
background
surface
surfaceVariant
textPrimary
textSecondary
border
success
warning
error
live
recording
~~~

Use ThemeExtension where Material ColorScheme is insufficient.

---

# 18. Theme modes

Required:

~~~text
Light
Dark
System
~~~

Behavior:

- default = System;
- persisted locally;
- changing theme updates immediately;
- no app restart;
- every screen must render in light and dark;
- dialogs/sheets/navigation/skeletons must follow the theme.

Do not maintain two separate widget trees for light and dark.

---

# 19. Localization

Initial locales:

~~~text
vi
en
~~~

Use ARB/localization resources.

Do not hard-code product text directly in screen widgets unless the text is not user-facing.

Required localized areas:

- navigation labels;
- screen titles;
- buttons;
- form validation;
- status presentation;
- error presentation;
- confirmation dialogs;
- billing labels;
- empty states;
- onboarding;
- theme names;
- language names.

Persist selected language.

If no language was selected, use system locale with a supported-locale fallback.

---

# 20. Accessibility baseline

Each implementation phase must preserve:

- touch targets appropriate for mobile;
- readable contrast;
- text scaling without major clipping;
- semantics labels for icon-only actions;
- no color-only communication for status;
- loading announcements where reasonable;
- clear destructive-action confirmation.

---

# 21. PHASE 0 — Flutter project bootstrap

## Goal

Create a clean, runnable Flutter application under apps/mobile.

No product screen implementation beyond a simple bootstrap shell.

## Tasks

Create Flutter project with:

~~~text
apps/mobile/
~~~

Configure:

- Android app package/bundle ID placeholder appropriate for SaveStream;
- iOS bundle ID placeholder appropriate for SaveStream;
- minimum SDK versions supported by current Flutter stable;
- Dart analysis;
- formatting;
- environment config structure;
- base dependency setup;
- test folders;
- asset folders.

Install only the foundation dependencies:

- flutter_riverpod;
- go_router;
- dio;
- flutter_secure_storage;
- shared_preferences;
- localization packages required by Flutter.

Create:

~~~text
lib/main.dart
lib/app/app.dart
lib/app/bootstrap.dart
lib/app/router/
lib/app/theme/
lib/app/localization/
lib/core/
lib/features/
~~~

## Environment configuration

Prepare environments conceptually:

~~~text
mock
dev
staging
production
~~~

Phase 0 may only implement mock/dev switching.

No production secret belongs in the Flutter repository.

## Deliverables

- Flutter project compiles;
- Android debug build starts;
- iOS project is generated correctly;
- app launches to bootstrap screen;
- analyzer passes;
- unit test command works.

## Definition of Done

~~~text
flutter pub get
flutter analyze
flutter test
flutter run
~~~

work from apps/mobile.

## Explicitly not in Phase 0

- full design system;
- auth screens;
- channels;
- recordings;
- real API integration.

---

# 22. PHASE 1 — Brand foundation + design system

## Goal

Convert the approved SaveStream mobile design into reusable Flutter primitives.

## Tasks

Import approved logo/icon assets.

Create:

~~~text
AppColors
AppSpacing
AppRadius
AppTypography
AppTheme
AppThemeMode
~~~

Build reusable primitives:

~~~text
SsButton
SsIconButton
SsTextField
SsPasswordField
SsCard
SsStatusChip
SsSectionHeader
SsListTile
SsEmptyState
SsErrorState
SsSkeleton
SsBottomSheet
SsDialog
SsAvatar
SsAppBar
~~~

Names may change if the codebase establishes a better convention, but there must be one consistent component set.

## Theme

Implement:

- light;
- dark;
- system;
- persisted preference.

## Localization foundation

Implement:

- vi;
- en;
- persisted preference;
- locale switch without restart.

## Required tests

Widget tests for:

- primary button;
- input;
- status chip;
- theme switch;
- locale switch.

Golden tests for a small foundation set if stable in CI.

## Definition of Done

A gallery/dev screen can display all shared components in both themes and both languages.

No feature should begin creating one-off buttons/cards if a shared component already exists.

---

# 23. PHASE 2 — App shell + navigation

## Goal

Build the mobile navigation architecture from the approved design.

## Tasks

Create:

- public auth shell;
- onboarding route group;
- authenticated shell;
- bottom navigation;
- route guards;
- placeholder screens for main tabs;
- Add Channel navigation.

Main tabs:

~~~text
Home
Channels
Recordings
Settings
~~~

Persist tab state with shell navigation.

## Auth state

At this phase use a mock session state only.

Example conceptual states:

~~~text
unknown
signedOut
needsOnboarding
signedIn
~~~

## Definition of Done

The app can navigate through:

~~~text
Welcome
→ Sign in
→ Onboarding
→ Home shell
→ Channels
→ Recordings
→ Settings
~~~

using mock auth state.

Deep-link-safe route definitions exist even if universal/app links are not configured yet.

---

# 24. PHASE 3 — Authentication + onboarding UI

## Goal

Complete authentication and onboarding UX using mock repositories.

## Screens

- Welcome;
- Sign in;
- Register;
- Forgot password;
- Verify email;
- Onboarding;
- permission/legal acknowledgement;
- completion.

## Domain interfaces

Create:

~~~text
AuthRepository
SessionRepository
OnboardingRepository
~~~

Initial implementations:

~~~text
MockAuthRepository
LocalOnboardingRepository
~~~

## Forms

Implement:

- email validation;
- password field behavior;
- confirm password where required;
- disabled/loading submit;
- field-level API-style errors;
- generic auth failure;
- retry.

Do not overfit password validation rules until backend rules are finalized.

## Mock scenarios

Support:

- successful sign in;
- invalid credentials;
- email not verified;
- rate limited;
- forgot-password success;
- verify success;
- verify expired/error.

## Definition of Done

All auth/onboarding flows are fully interactive with mock repositories and work in VI/EN + Light/Dark.

No real backend endpoint is required.

---

# 25. PHASE 4 — Home dashboard

## Goal

Implement the Home experience from the approved mobile design.

## Domain data

Create a Home aggregate/view model assembled from repositories, not a backend-only god DTO unless the backend later exposes a dashboard endpoint.

Sections:

- greeting/profile summary;
- active recording;
- watched channels;
- credit/usage summary;
- recent recordings;
- quick Add Channel action.

## States

Implement:

- populated;
- first-time/empty;
- active recording;
- processing recording;
- insufficient credit warning;
- loading;
- error.

## Mock repository inputs

Use existing interfaces for:

~~~text
WatchRepository
RecordingRepository
CreditRepository
~~~

The Home controller may combine their data.

## Definition of Done

Home looks complete and behaves correctly without requiring the backend.

---

# 26. PHASE 5 — Channels / Watches

## Goal

Complete Watch management UI shown to users as Channels.

## Screens

- Channels list;
- Add Channel;
- Channel detail;
- pause confirmation if needed;
- resume action;
- remove/delete confirmation.

## Domain models

Expected concepts:

~~~text
Watch
Creator
LiveStatus
WatchStatus
~~~

Do not create fields that conflict with the backend handoff.

## Channel list states

Support:

- active/offline;
- live;
- paused;
- paused_insufficient_credit;
- paused_error;
- disabled;
- empty;
- loading;
- error.

## Add Channel

Initial input:

~~~text
TikTok username or supported source input
~~~

The UI may normalize visual input, but final source interpretation belongs to backend.

Show content-permission acknowledgement where appropriate.

## Mock behavior

Add Channel should create a mock Watch visible in the list.

Pause/resume/delete should modify mock repository state.

## Definition of Done

Channels can be added, inspected, paused/resumed and removed in a fully interactive mock flow.

---

# 27. PHASE 6 — Recordings

## Goal

Implement the complete recording lifecycle UI.

## Screens

- Recordings list;
- filter/sort controls;
- Recording detail.

## Canonical status support

Every status must have a deliberate rendering:

~~~text
queued
resolving
waiting_live
recording
processing
uploading
completed
failed
stop_requested
stopped
~~~

## Recording detail

Display as available:

- creator/source;
- status;
- start time;
- elapsed/duration;
- size/bytes;
- estimated max cost;
- actual cost;
- artifact availability;
- error presentation;
- allowed actions.

Use backend-style:

~~~text
actions.can_stop
actions.can_retry
actions.can_delete
~~~

Even mock data should provide this shape.

## Active recording

Simulate progress over time in mock mode.

The UI must not depend on a real media stream.

## Completed recording

Expose mock:

- playback placeholder/preview when design calls for it;
- download action;
- file metadata.

Actual presigned URL behavior comes later.

## Filters

At minimum prepare:

- status;
- date/sort if part of approved UX.

Filter implementation must be compatible with server-side pagination later.

## Definition of Done

A tester can move through believable mock examples for every recording state.

---

# 28. PHASE 7 — Credits, Usage and Billing UI

## Goal

Implement all financial/usage screens without trusting the client for financial truth.

## Credit model

Use:

~~~text
posted
reserved
available
~~~

Explain reserved credits to the user.

## Screens

- Usage/Credits overview;
- transactions;
- package list;
- checkout launch state;
- payment pending;
- paid;
- failed.

## Important rule

Flutter never sets payment to paid based on a browser/deep-link redirect.

Mock payment flow may simulate backend confirmation but code structure must reflect:

~~~text
checkout
→ return to app
→ query backend payment order
→ render actual backend state
~~~

## Definition of Done

All billing screens are complete with mocks and financial values are presented as backend-owned data.

---

# 29. PHASE 8 — Settings + profile

## Goal

Complete app-level user settings.

## Screens

- Settings;
- Profile;
- Language;
- Theme;
- Sign out;
- account/session entries when supported;
- account deletion entry when supported.

## Local settings

Implemented locally:

- language;
- theme;
- onboarding-complete flag if backend does not own it yet.

## Backend-owned settings/profile

Use mock repository until API is available.

## Definition of Done

User can change theme/language immediately, edit mock profile data and sign out through the shared session controller.

---

# 30. PHASE 9 — API client foundation

## Goal

Introduce real API transport without yet converting every feature.

This phase is done only after the backend API contract is stable enough.

## API client responsibilities

Create:

~~~text
ApiClient
AuthInterceptor
RequestId handling
ApiError parser
Idempotency helper
Cursor pagination types
~~~

## Base URL

Configured by environment.

No hard-coded production URL scattered in code.

## API error envelope

Support:

~~~json
{
  "error": {
    "code": "INSUFFICIENT_CREDITS",
    "message": "Available credit is insufficient",
    "request_id": "req_...",
    "retryable": false,
    "details": {}
  }
}
~~~

Create typed:

~~~text
ApiException
ApiErrorCode
~~~

Unknown error codes must degrade safely.

## Idempotency

Generate a UUID-style unique key once per logical mutation attempt where required.

Retries of the same logical request reuse the same key.

New user action generates a new key.

## Cursor pagination

Use shared model:

~~~text
items
next_cursor
has_more
~~~

Do not make feature-specific pagination frameworks.

## Definition of Done

API transport can call a health/test endpoint in dev while all feature repositories can still remain mock.

---

# 31. PHASE 10 — Real authentication integration

## Goal

Replace mock auth with backend auth.

Expected endpoints include:

~~~text
POST /v1/auth/register
POST /v1/auth/verify-email
POST /v1/auth/resend-verification
POST /v1/auth/login
POST /v1/auth/refresh
POST /v1/auth/logout
POST /v1/auth/logout-all
POST /v1/auth/forgot-password
POST /v1/auth/reset-password

GET /v1/me
PATCH /v1/me
~~~

## Required behavior

- access token handled in memory;
- refresh token stored securely;
- refresh rotation supported;
- logout clears secure credentials;
- revoked session transitions to signed-out state;
- app launch restores session through refresh/me flow;
- no token appears in logs.

## Definition of Done

App can register/login/restore/logout against dev/staging API.

Mock auth remains usable under mock environment if useful for UI development.

---

# 32. PHASE 11 — Real Channels / Watch integration

## Goal

Replace MockWatchRepository with ApiWatchRepository.

Expected endpoints:

~~~text
POST   /v1/watches
GET    /v1/watches
GET    /v1/watches/{watch_id}
PATCH  /v1/watches/{watch_id}
DELETE /v1/watches/{watch_id}
POST   /v1/watches/{watch_id}/resume
~~~

Optionally use live-status endpoint when backend contract is ready.

## Requirements

- cursor pagination;
- error-code mapping;
- optimistic UI only when rollback is safe;
- authoritative status refresh after mutation;
- insufficient-credit state supported;
- source data preserved correctly.

## Definition of Done

Channels screens operate against real dev/staging backend without UI changes.

---

# 33. PHASE 12 — Real Recordings integration

## Goal

Connect recording creation/list/detail/stop/artifact APIs.

Expected endpoints:

~~~text
POST   /v1/recordings
GET    /v1/recordings
GET    /v1/recordings/{recording_id}
POST   /v1/recordings/{recording_id}/stop
GET    /v1/recordings/{recording_id}/events
GET    /v1/recordings/{recording_id}/artifacts
POST   /v1/artifacts/{artifact_id}/download-url
DELETE /v1/recordings/{recording_id}
~~~

## Create recording

Must include Idempotency-Key.

Do not retry creation with a new key after an ambiguous network failure unless the user intentionally initiates a new logical recording.

## Realtime progress

Preferred mobile strategy:

~~~text
HTTP streaming SSE
~~~

Support:

- event ID;
- sequence;
- reconnect;
- Last-Event-ID where backend supports it;
- polling fallback.

## Polling fallback

If SSE is unavailable:

~~~text
GET /v1/recordings/{id}
~~~

with exponential/backoff-aware polling.

## Artifact URLs

Presigned URLs are ephemeral.

Do not treat them as persistent model fields.

Fetch a fresh URL when needed.

## Definition of Done

A user can:

~~~text
create recording
→ see queued/waiting
→ see recording progress
→ request stop
→ see processing
→ see ready artifact
→ request download URL
~~~

against real backend.

---

# 34. PHASE 13 — Real Credits + Billing integration

## Goal

Replace mock financial repositories.

Expected endpoints:

~~~text
GET /v1/credits/balance
GET /v1/credits/transactions
GET /v1/credits/reservations
GET /v1/pricing

GET  /v1/billing/packages
POST /v1/billing/payment-orders
GET  /v1/billing/payment-orders
GET  /v1/billing/payment-orders/{payment_order_id}
POST /v1/billing/payment-orders/{payment_order_id}/checkout
~~~

## Checkout

Mobile may open:

- system browser;
- provider SDK only if explicitly approved later;
- provider deep link returned by backend.

No payment provider secret in the app.

## Confirmation

After return:

~~~text
poll/query payment order
~~~

until backend reports terminal/presentable state.

## Definition of Done

Credits and billing reflect backend state and duplicate client actions cannot accidentally create duplicate orders due to correct idempotency behavior.

---

# 35. PHASE 14 — Reliability, UX polish and offline behavior

## Goal

Make the app resilient enough for beta use.

## Tasks

- standardized retry UX;
- network connectivity handling;
- stale-data indicators where caching is used;
- pull-to-refresh;
- pagination retry;
- skeleton consistency;
- background/foreground recording-status refresh;
- app lifecycle refresh;
- session-expiry handling;
- global error boundary patterns;
- crash-safe local preference handling.

Do not implement complex offline mutation queues unless product requirements explicitly call for them.

## Definition of Done

Common network failures do not leave the UI in impossible states.

---

# 36. PHASE 15 — Testing and quality gate

## Goal

Establish confidence before release builds.

## Unit tests

Cover:

- status mapping;
- pagination;
- error-code mapping;
- repository logic;
- auth refresh coordination;
- idempotency-key lifecycle;
- theme/language persistence.

## Widget tests

Cover major screens:

- sign in;
- Home;
- Channels;
- Add Channel;
- Recordings;
- Recording detail;
- Credits;
- Settings.

## Golden tests

Recommended for stable high-value screens in:

~~~text
Light EN
Dark EN
Light VI
Dark VI
~~~

Do not create an excessive golden matrix for every tiny widget.

## Integration tests

At minimum:

~~~text
mock:
launch
→ sign in
→ onboarding
→ add channel
→ inspect recording
→ change language/theme
→ sign out
~~~

Later staging integration:

~~~text
login
→ create/watch
→ recording
→ stop/completion
~~~

where environment data is safe and deterministic.

## Definition of Done

CI passes analyzer + tests and major mobile flows have regression coverage.

---

# 37. PHASE 16 — Android/iOS release preparation

## Goal

Prepare beta-ready distributable builds.

## Android

- package/application ID finalized;
- app name SaveStream;
- launcher icons;
- splash;
- permissions audit;
- ProGuard/R8 as appropriate;
- signing configuration through secure CI secrets;
- release build.

## iOS

- bundle ID finalized;
- app icons;
- launch assets;
- capabilities audit;
- URL/deep-link configuration when needed;
- signing through Apple/CI credentials;
- release/archive validation.

## Store compliance

Before public submission:

- Terms link;
- Privacy Policy link;
- content-permission wording;
- recording responsibility wording;
- account deletion flow as required;
- data collection disclosure;
- payment policy compliance;
- no misleading TikTok affiliation branding.

## Definition of Done

Android and iOS release artifacts can be generated from a documented CI/release process.

---

# 38. Phase dependency graph

Recommended order:

~~~text
Phase 0  Bootstrap
   ↓
Phase 1  Design System
   ↓
Phase 2  Navigation
   ↓
Phase 3  Auth + Onboarding Mock
   ↓
 ┌────────────────────────────────────────┐
 ↓                ↓             ↓         ↓
P4 Home        P5 Channels    P6 Rec.   P7 Credits
 └────────────────────────────────────────┘
                     ↓
                 P8 Settings
                     ↓
                 P9 API Core
                     ↓
                 P10 Auth API
                     ↓
        ┌────────────┼────────────┐
        ↓            ↓            ↓
     P11 Watch    P12 Rec.     P13 Billing
        └────────────┼────────────┘
                     ↓
                 P14 Polish
                     ↓
                 P15 Tests
                     ↓
                 P16 Release
~~~

Phases 4–8 may be developed in parallel once Phase 1–3 foundations are stable.

Real API phases depend on corresponding backend endpoints being ready.

---

# 39. Backend dependency matrix

| Mobile phase | Backend required? |
|---|---|
| Phase 0 Bootstrap | No |
| Phase 1 Design System | No |
| Phase 2 Navigation | No |
| Phase 3 Auth UI | No, mock |
| Phase 4 Home | No, mock |
| Phase 5 Channels | No, mock |
| Phase 6 Recordings | No, mock |
| Phase 7 Credits/Billing UI | No, mock |
| Phase 8 Settings | No, mock |
| Phase 9 API Core | Contract/dev API helpful |
| Phase 10 Auth API | Auth endpoints required |
| Phase 11 Watch API | Watch endpoints required |
| Phase 12 Recording API | Recording + artifact + event endpoints required |
| Phase 13 Credits/Billing API | Credit/billing endpoints required |
| Phase 14 Reliability | Partial/real backend useful |
| Phase 15 Integration tests | Stable backend/mock environment |
| Phase 16 Release | Staging + production configuration |

---

# 40. Git workflow

Recommended branch pattern:

~~~text
mobile/phase-0-bootstrap
mobile/phase-1-design-system
mobile/phase-2-navigation
mobile/phase-3-auth-onboarding
mobile/phase-4-home
mobile/phase-5-channels
mobile/phase-6-recordings
mobile/phase-7-credits-billing
mobile/phase-8-settings
mobile/phase-9-api-core
...
~~~

Each phase should normally become one PR or a small series of focused PRs.

Avoid giant PRs combining several unrelated phases.

---

# 41. Commit expectations

Use focused commits.

Examples:

~~~text
feat(mobile): bootstrap Flutter application
feat(mobile): add SaveStream theme tokens
feat(mobile): implement auth flow screens
feat(mobile): add mock watch repository
feat(mobile): implement recording lifecycle UI
test(mobile): add recording status mapper tests
~~~

Do not commit:

- API secrets;
- signing keys;
- personal local config;
- generated build output;
- private certificates.

---

# 42. Definition of Done for every UI phase

Every UI phase is incomplete unless all applicable items pass:

- compiles;
- analyzer passes;
- no obvious overflow on common phone sizes;
- Light mode works;
- Dark mode works;
- Vietnamese works;
- English works;
- loading state exists;
- empty state exists where relevant;
- error state exists;
- mock success path works;
- shared components are reused;
- no backend secret/client business authority added;
- tests for important controllers/mappers/widgets are included.

---

# 43. Definition of Done for every API phase

Every API integration phase is incomplete unless:

- mock repository can still be used in mock environment when appropriate;
- API repository implements the existing domain interface;
- DTO → domain mapping is centralized;
- API errors map from error.code;
- request cancellation/timeouts are reasonable;
- auth behavior is consistent;
- pagination works;
- duplicate mutations are protected by Idempotency-Key where required;
- logging contains no token;
- UI does not need to be rewritten.

---

# 44. Rules for generated API clients

If backend publishes stable OpenAPI:

Preferred direction:

~~~text
OpenAPI
  ↓
generated transport DTO/client
  ↓
mobile repository adapter
  ↓
domain model
  ↓
UI
~~~

Do not expose generated transport classes throughout widgets.

This keeps the UI insulated from contract-generation changes.

Generated files must have a reproducible generation command.

Do not manually edit generated code.

---

# 45. Error presentation policy

Backend code drives logic.

Example:

~~~text
INSUFFICIENT_CREDITS
~~~

may map to:

- low-credit banner;
- Add credits CTA;
- paused Watch explanation.

Example:

~~~text
AUTH_EMAIL_NOT_VERIFIED
~~~

may route to verification UI.

Example:

~~~text
RECORDING_ALREADY_ACTIVE
~~~

may refresh/open existing recording.

Unknown codes fall back to a generic error.

Never use substring matching on backend message.

---

# 46. Recording action policy

Flutter must use server-provided action capabilities when available.

Example:

~~~json
{
  "actions": {
    "can_stop": true,
    "can_retry": false,
    "can_delete": false
  }
}
~~~

Do not reproduce the entire backend state machine in button visibility logic.

The server still enforces the action even if the app UI is stale.

---

# 47. Credit display policy

Always distinguish:

~~~text
posted
reserved
available
~~~

Do not make reserved credit look like a finalized charge.

Recording screens may show:

- estimated max cost;
- actual cost only after backend returns it.

No floating-point financial calculations should determine authoritative values in Flutter.

---

# 48. Payment policy

Flutter is not the source of truth for payment.

Never:

~~~text
redirect returned = paid
~~~

Correct flow:

~~~text
create payment order
→ create/open checkout
→ return/deep link
→ query payment order
→ backend reports paid/pending/failed
→ display result
~~~

---

# 49. Security baseline

- no secrets in source;
- no refresh token in SharedPreferences;
- no token logs;
- HTTPS-only production;
- debug logging disabled/reduced in production;
- deep-link parameters validated;
- presigned URLs treated as temporary credentials;
- sensitive values excluded from analytics/crash breadcrumbs where possible.

---

# 50. Performance baseline

Avoid premature optimization, but maintain:

- lazy list rendering;
- paginated recordings/channels;
- image caching appropriate for avatars;
- no rebuild-heavy global state;
- no polling when screen/app no longer needs it;
- stop SSE/polling subscriptions when disposed;
- app lifecycle aware realtime refresh.

---

# 51. Deliverable expected after mock UI phases

After Phases 0–8, the app should already look and behave like a complete product even without the real API.

A stakeholder should be able to:

~~~text
launch app
→ register/sign in mock
→ onboarding
→ Home
→ add a Channel
→ see Channel status
→ view recordings
→ inspect active/processing/ready/failed examples
→ view credits/packages
→ change language
→ change theme
→ edit profile
→ sign out
~~~

This is the UI milestone.

---

# 52. Deliverable expected after API phases

After Phases 9–13:

~~~text
mock product
→ real SaveStream client
~~~

without replacing presentation architecture.

User should be able to perform the same flow against backend APIs.

---

# 53. What the coding agent must NOT do

Do not:

1. put TikTok recorder code into Flutter;
2. call TikTok private endpoints directly from mobile;
3. hard-code backend secrets;
4. make client payment success authoritative;
5. invent alternate recording/watch enum values;
6. duplicate web React code mechanically into Flutter;
7. use raw hex values throughout feature widgets;
8. hard-code Vietnamese/English strings directly in every widget;
9. create a second routing/state-management stack;
10. couple widgets directly to Dio;
11. store auth refresh token in SharedPreferences;
12. rewrite UI when changing from mock repository to API repository;
13. use error.message for program logic;
14. implement infinite polling without lifecycle cancellation;
15. fetch and persist presigned URLs as permanent media links.

---

# 54. Phase handoff format

When the user says:

~~~text
Làm Phase N
~~~

the agent should:

1. reread this plan;
2. inspect current apps/mobile state;
3. inspect relevant backend/OpenAPI contract if Phase N integrates API;
4. implement only Phase N plus unavoidable small prerequisites;
5. run Flutter formatting/analyzer/tests;
6. summarize changed files;
7. note any contract assumption;
8. push code under apps/mobile;
9. avoid silently beginning the next phase.

---

# 55. Suggested first implementation sequence

Start with:

~~~text
Phase 0 — Bootstrap
~~~

Then:

~~~text
Phase 1 — Design System
Phase 2 — Navigation
Phase 3 — Auth + Onboarding UI
~~~

At that point the shared foundation is stable enough to build Home, Channels, Recordings, Credits and Settings rapidly.

Do not begin real API integration before the backend contract required by that feature is stable.

---

# 56. Final target

The final architecture should remain:

~~~text
Flutter UI
    ↓
Controller / Provider
    ↓
Domain Repository
    ↓
┌───────────────────┬──────────────────┐
│ Mock Repository   │ API Repository   │
└───────────────────┴──────────────────┘
                          ↓
                     SaveStream API
                          ↓
                  backend workers/engine
~~~

Flutter is responsible for:

- presentation;
- local UI state;
- secure session credential storage;
- navigation;
- localization;
- API interaction.

Backend is responsible for:

- authentication authority;
- TikTok resolving;
- Watch orchestration;
- recording;
- processing;
- storage;
- pricing;
- credits;
- payments;
- authorization;
- final state.

This boundary must remain intact through all phases.
