# SaveStream Mobile

Flutter mobile client for SaveStream.

## Current milestone

Phase 16 includes:

- Material 3 Light / Dark / System themes and VI / EN localization from Phase 1;
- `MaterialApp.router` with `go_router`;
- complete onboarding UI with cloud-recording explanation and authorization consent;
- Sign in, Register, Verify Email, and Forgot Password flows backed by an AuthRepository;
- stateful four-tab shell: Home, Channels, Recordings, Settings;
- preserved navigation stacks with `StatefulShellRoute.indexedStack`;
- global Flutter/router error handling and app lifecycle observer hooks;
- Riverpod repository providers;
- repository interfaces for Watches, Recordings, Credits, and Billing;
- mock scenarios: success, loading, empty, error, and offline-like;
- seed mock Watches and Recordings using backend-aligned statuses;
- full Channels / Watches list with LIVE/offline, Watch status, auto-record, last checked/live metadata;
- Add Channel / Watch flow with TikTok username/profile URL input, auto-record setting, and authorization confirmation;
- Channel Detail with monitoring status, auto-record toggle, pause/resume, delete, latest recording, and recording history;
- mock Watch mutations for create, pause, resume, toggle auto-record, and delete;
- Watch status coverage for active, paused, paused_insufficient_credit, paused_error, and disabled;
- full Recordings list with All / Active / Completed / Failed filters;
- cursor-based mock pagination with Load More, pull-to-refresh, filter-specific empty states, skeletons, and retryable errors;
- recording cards with creator, lifecycle status, start time, duration, size, cost, artifact, thumbnail, and progress metadata;
- lifecycle-specific detail UI for queued, resolving, waiting_live, recording, processing, uploading, completed, failed, stop_requested, and stopped;
- Stop / Retry / Delete actions driven by backend-aligned `actions.can_stop`, `actions.can_retry`, and `actions.can_delete` flags;
- mutable mock recording actions for stop, retry, and delete, with Home and Channel recording history refresh signals;
- artifact Play / Download UI gated by artifact readiness and reserved for real backend integration in Phase 12;
- Credits screen with backend-authoritative integer posted, reserved, and available balances;
- real credit ledger, reservation history, active reservation count, pricing metadata, empty/loading/error states, and pull-to-refresh;
- Billing screen with backend credit packages, exact minor-unit money values, recent payment orders, and buy CTA;
- payment order status coverage for created, pending, paid, failed, cancelled, expired, partially_refunded, and refunded;
- real checkout flow that creates an order, creates provider checkout, returns through the `savestream:` deep link, and only treats payment as successful after backend status becomes `paid`;
- Settings sections for Profile, Credits/Billing, Preferences, Legal, Account actions, and Developer tools;
- Profile screen backed by `ProfileRepository`, including email and verified/unverified state;
- dedicated Language screen for English / Vietnamese and Theme screen for Light / Dark / System;
- `AppSettingsStore` abstraction for local preferences, with production persistence via `SharedPreferencesAsync`;
- bootstrap restores persisted theme/language before `runApp` so preferences survive app restart;
- Notifications placeholder kept separate until a backend notification contract exists;
- Privacy Policy and Terms of Use navigation entries are present without inventing production URLs; published links remain a release dependency;
- Logout and Delete Account actions go through the auth/session abstraction, with destructive confirmation for account deletion;
- Settings entries for Credits and Billing plus direct Home low-credit navigation;
- auth mock outcomes for invalid credentials, unverified email, rate limits, server failure, and offline-like behavior;
- aggregated Home Dashboard via `HomeDashboardViewModel` / `homeDashboardProvider`;
- responsive Home metrics for available credit, active recordings, and monitored channels;
- usage summary, Add Channel CTA, low-credit and failed-recording alerts;
- active recording, monitored channel, and recent recording cards linked to detail routes;
- Home skeleton, empty-account, retryable error, and pull-to-refresh states;
- the Phase 1 component gallery retained at `/dev/components`;
- typed Dio `ApiClient` foundation using `AppConfig.apiBaseUrl`;
- centralized connect/send/receive timeouts with no infinite timeout path;
- access-token provider abstraction plus bearer auth interceptor, without persisting auth tokens in SharedPreferences;
- backend error-envelope mapping into typed `ApiError` / `ApiException`, branching on `error.code` rather than message text;
- typed categories for unauthorized, insufficient credits, conflict, rate limit, server, network, timeout, and malformed responses;
- request ID extraction from the backend envelope or response headers;
- controlled retry for safe GET/HEAD requests only; mutation commands are not retried automatically;
- `IdempotencyContext` / key-generator foundation so one logical command can reuse one key across retries;
- fake Dio adapter tests covering 2xx decode, 401, 402, 409, 429, 5xx, timeout, offline/network failure, malformed envelopes, request IDs, auth headers, retry behavior, and idempotency reuse;
- real mobile authentication against the frozen `/v1` identity contract;
- Register, Verify Email, Resend Verification, Login, Refresh, Logout, Forgot Password, Reset Password, and Delete Account wired to backend APIs;
- login explicitly sends `client_type=mobile` and consumes the mobile refresh token response;
- access tokens are held only in memory through `MemoryAccessTokenStore`;
- rotating refresh tokens are persisted through `FlutterSecureStorage`, not SharedPreferences;
- app bootstrap attempts secure refresh-token session restore before `runApp`;
- concurrent refresh attempts are serialized so one refresh rotation is in flight at a time;
- authenticated requests get one automatic 401 refresh-and-replay attempt;
- revoked/reused refresh sessions clear local access/refresh credentials and return the app to unauthenticated routing;
- a failed secure-storage write after refresh rotation invalidates local credentials so the stale refresh token is never reused;
- Android secure-storage requirements are configured with API 23 minimum and Auto Backup disabled;
- iOS Keychain Sharing entitlements are configured for Debug/Profile and Release;
- Verify Email and Reset Password screens use backend one-time tokens and can accept a `token` query parameter;
- Phase 10 auth/session unit tests cover mobile login payloads, token rotation, restart restore, serialized refresh, 401 replay, session revocation, logout cleanup, storage failure, and backend error-code mapping;
- real Channels / Watch integration against `/v1/watches`;
- typed Watch response mapping for `active`, `paused`, `paused_insufficient_credit`, `paused_error`, and `disabled`;
- typed live-status mapping for `unknown`, `offline`, and `live`;
- backend Watch source mapping for username, profile URL, and room ID responses while the Add Channel UI keeps its existing username/URL inputs;
- cursor pagination is consumed inside `ApiWatchRepository` so existing Channels/Home screens keep the same `listWatches()` contract;
- create, detail, auto-record update, pause, resume, and delete now call the real authenticated Watch API in production;
- `RESOURCE_NOT_FOUND` detail responses map to the existing nullable repository contract without exposing JSON to presentation code;
- duplicate Watch conflicts and resume `INSUFFICIENT_CREDITS` use typed API categories instead of message parsing;
- Watch mutations always invalidate/refetch list, detail, and Home Watch state after success or failure, reconciling server-side partial state such as a 402 resume that persists `paused_insufficient_credit`;
- Home automatically uses real Watch data through the existing shared `watchRepositoryProvider`;
- Watch state remains REST-based with refresh/refetch; no Watch-specific SSE contract is invented;
- Phase 11 tests cover status mapping, creator fallback, cursor pagination, create/mutation payloads, 404 handling, 402 handling, malformed status rejection, and failed-mutation reconciliation;
- real Recordings integration against the frozen `/v1/recordings` contract;
- typed Recording response mapping for every lifecycle status plus backend-owned `actions.can_stop`, `actions.can_retry`, and `actions.can_delete`;
- cursor pagination remains behind `RecordingRepository`, including client-side Active filtering without dropping later cursor pages;
- real create, detail, stop, delete, artifact list, and artifact download-URL calls through the authenticated API client;
- recording creation uses UUID v4 `Idempotency-Key` values because the backend validates the header as a UUID;
- Retry follows the available backend contract by creating a new Recording from the failed Recording source when `actions.can_retry` is true; no nonexistent retry endpoint is invented;
- Channel Detail adds Record now and creates a Recording from the resolved Watch source;
- Channel recording history reconciles by Watch source/creator because backend Recording responses do not expose a `watch_id`;
- authenticated SSE is consumed from `GET /v1/recordings/{id}/events` with Bearer auth, `Last-Event-ID`, event sequence deduplication, and canonical REST refetch after events;
- realtime streams reconnect with bounded exponential backoff and fall back to `GET /v1/recordings/{id}` when SSE disconnects or fails;
- Recording Detail subscribes to realtime only while the app is foregrounded; backgrounding releases the auto-disposed stream and foregrounding reconnects from a fresh REST snapshot;
- terminal Recording state invalidates artifact data so completed/stopped artifacts can appear without restarting the screen;
- artifact Play / Download now lists real artifacts and requests a fresh presigned download URL for every action instead of persisting expiring URLs;
- Recording mutations invalidate list, canonical detail, realtime detail, artifacts, Home, and Channel history signals so UI state reconciles after commands;
- Phase 12 tests cover UUID idempotency, all Recording statuses/action flags, cursor pagination, Active filtering, stop/delete endpoints, retry semantics, artifact URLs, authenticated SSE parsing, `Last-Event-ID`, reconnect, and sequence deduplication;
- real Credits integration against `/v1/credits/balance`, `/v1/credits/transactions`, `/v1/credits/reservations`, and `/v1/pricing`;
- Credits remain integer-only end-to-end; the app never calculates final recording charges client-side;
- cursor pagination for credit transactions and reservations stays inside `ApiCreditsRepository`;
- an unconfigured backend pricing rule (`503 SERVICE_UNAVAILABLE`) leaves balance/ledger/reservations usable and displays pricing as unavailable;
- Home available-credit metric now comes from the real credit balance while unrelated account metrics keep their existing repository boundary;
- real Billing integration against packages, payment-order list/detail, create-order, and checkout endpoints;
- create-order and checkout reuse one UUID idempotency key across retries of the same logical operation;
- checkout opens the provider externally and returns through the `savestream:` custom URL scheme configured on Android and iOS;
- returning from checkout never marks an order paid; the app polls/refetches backend payment status until a terminal state;
- Credits/Home state is invalidated only after backend-confirmed `paid`, so the backend/webhook remains authoritative for posted credit;
- Phase 13 tests cover integer credit mapping, ledger/reservation pagination, pricing-unavailable behavior, all payment statuses, money minor units, idempotency reuse, absolute checkout return URIs, backend polling, and no client-side credit mutation;
- shared async error classification for offline-like, recoverable, and non-recoverable failures;
- Retry actions are shown only when the failure is retryable and the screen has a real retry operation;
- backend request IDs are shown as support detail without exposing raw exceptions or branching on backend message text;
- initial async loads keep screen-specific skeletons that approximate final layouts instead of full-screen spinners;
- refreshes on Home, Channels, Channel Detail, Credits, Billing, Recording Detail, and Profile keep existing data visible with a thin progress indicator;
- Recording list refresh now preserves the current page and filter, surfaces refresh failures inline, and keeps load-more failures local to the pagination section;
- Billing Return uses a layout-matched skeleton instead of a full-screen spinner while payment status loads;
- mutation failures use shared inline feedback; actions that cannot be safely replayed no longer show a misleading Retry button;
- async state localization covers refreshing, non-retryable failures, and Request ID support detail in EN/VI;
- Phase 14 widget tests cover offline retry behavior, non-retryable behavior, request IDs, authoritative retry overrides, and stale-content refresh progress;
- controller unit coverage for Auth, Watch, Recording, and Billing state transitions/invalidation;
- Auth controller tests cover successful sign-in and unverified-email routing state;
- Watch/Recording controller tests verify list/detail/revision reconciliation after both successful and failed mutations;
- Billing controller tests verify create-order, checkout, refresh, and snapshot-change notifications;
- full-app critical-flow tests exercise navigation and state through the real app shell/router with repository boundaries;
- critical automated flows cover launch -> onboarding -> login -> home, add channel -> channel detail, active recording -> stop -> stopped, and billing -> pending -> paid;
- the Phase 15 suite reuses prior DTO/domain mapper, error/status mapping, idempotency, auth session/token, auth form, status-variant, credit, theme/language, and async-state coverage instead of duplicating those cases;
- final Phase 15 validation runs 96 passing Flutter tests under the same CI format/analyze/test gates.

Authentication, Channels/Watch management, Recordings, Credits, and Billing now use real backend APIs in production bootstrap while mock implementations remain available for tests/previews. Home consumes real Watch/Recording data and the real available-credit balance; Profile remains on its current repository until a later integration phase.

## Requirements

- Flutter 3.47.0 stable for CI parity.
- Dart bundled with Flutter.

## Run locally

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter run
```

Environment defaults:

```text
local      -> http://10.0.2.2:8000
staging    -> https://staging-api.savestream.online
production -> https://api.savestream.online
```

Override build configuration with Dart defines when needed:

```bash
flutter run \
  --dart-define=APP_ENV=staging
```

Production native builds use App Store / Google Play in-app purchases for cloud-hour packs; there is no external hosted checkout path in the mobile app.

```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production
```

See `MOBILE_RELEASE.md` for signing and store submission requirements.

## Current architecture

```text
Auth screen
  -> AuthController
  -> AuthRepository
     -> ApiAuthRepository
        -> AuthPublicApi / AuthProtectedApi
        -> AuthSessionManager
        -> ApiClient

Channels / Home Watch slice
  -> Riverpod provider/controller
  -> WatchRepository
     -> ApiWatchRepository
        -> authenticated ApiClient

Recordings / Home Recording slice
  -> Riverpod provider/controller
  -> RecordingRepository
     -> ApiRecordingRepository
        -> authenticated ApiClient
        -> RecordingEventSource (SSE)

Other feature screen
  -> Riverpod provider/controller
  -> Repository interface
  -> Mock repository (until later phases)

MaterialApp.router
  -> guards
  -> StatefulShellRoute
  -> four preserved tab stacks
```

Repository boundaries remain intact: Watch and Recording production paths now use `ApiWatchRepository` and `ApiRecordingRepository` without moving raw HTTP/SSE parsing into presentation code, and the remaining mock-backed features can follow the same pattern.

Theme and language preferences are persisted locally through `AppSettingsStore`; production uses `SharedPreferencesAsync`. Authentication/session secrets are separate: access tokens stay in memory and refresh tokens use platform secure storage.

## API client foundation

Phase 9 adds Dio as the HTTP transport under `lib/core/api/`. The client takes its base URL from `AppConfig.apiBaseUrl`, applies centralized timeouts, can attach an access token through an `AccessTokenProvider`, and maps backend failures into typed exceptions before they reach repositories or presentation code.

Backend errors are expected in this shape:

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

Feature logic must branch on `error.code`, never on localized/free-form `message`. Request IDs are retained for support context. Safe GET/HEAD requests may use controlled retry; mutation commands are not automatically retried. Command features that require retry safety can carry an explicit `IdempotencyContext`, preserving one key for one logical operation.

Phase 9 remains the shared transport/error foundation. Phase 10 consumes it for real authentication, Phase 11 for Watch/Channel data, Phase 12 for Recording REST + SSE, Phase 13 for Credits + Billing, and Phase 14 standardizes how those async states are presented without changing transport semantics. Remaining feature repository migrations stay scoped to later phases.

## Secure authentication session

Production bootstrap starts unauthenticated, creates an `AuthRuntime`, then attempts `AuthSessionManager.restoreSession()` before building the app. A successful refresh rotates the backend refresh token, writes the new token to secure storage, stores the new access token only in RAM, and marks the app session authenticated.

The authenticated Dio client attaches the current access token and uses `ApiSessionRefreshInterceptor` for one 401 refresh-and-replay attempt. `AuthSessionManager` serializes concurrent refresh calls so a rotating refresh token cannot be consumed by multiple requests at once. If the backend reports `AUTH_SESSION_REVOKED`, or if the rotated refresh token cannot be persisted safely, the local session is invalidated instead of reusing stale credentials.

Platform setup for secure refresh-token storage is committed with the app: Android uses minimum API 23 and disables Auto Backup; iOS Runner configurations use Keychain Sharing entitlements. No access or refresh token is written to SharedPreferences.

## Watch API integration

Phase 11 replaces the production `MockWatchRepository` with `ApiWatchRepository` while keeping the existing screen and controller contracts. The repository maps the frozen Watch schema into `WatchSummary` and owns cursor traversal for `GET /v1/watches`, so presentation code never handles cursors or raw JSON.

Production Watch operations now use:

```text
POST   /v1/watches
GET    /v1/watches
GET    /v1/watches/{id}
PATCH  /v1/watches/{id}
DELETE /v1/watches/{id}
POST   /v1/watches/{id}/resume
```

The backend has no Watch-specific SSE endpoint. Watch/Channel state therefore uses the REST GET contract and normal provider refresh/refetch behavior. Mutation controllers invalidate list, detail, and Home Watch state in a `finally` path, so a failed mutation is reconciled with server truth. This matters for resume: the backend may persist `paused_insufficient_credit` before returning `402 INSUFFICIENT_CREDITS`.

## Recording API and realtime integration

Phase 12 replaces the production `MockRecordingRepository` with `ApiRecordingRepository` while preserving the existing Recordings list/detail and Home repository boundaries. REST operations use the authenticated client:

```text
POST   /v1/recordings
GET    /v1/recordings
GET    /v1/recordings/{id}
POST   /v1/recordings/{id}/stop
DELETE /v1/recordings/{id}
GET    /v1/recordings/{id}/artifacts
POST   /v1/artifacts/{id}/download-url
```

Recording creation sends a UUID v4 `Idempotency-Key`. Backend action flags remain authoritative: Stop, Retry, and Delete are shown and executed only according to `actions.can_stop`, `actions.can_retry`, and `actions.can_delete`. Because the frozen backend exposes no retry endpoint, an allowed retry creates a new Recording from the prior Recording source with a new idempotency key.

Realtime detail uses authenticated SSE at `GET /v1/recordings/{id}/events`. The client forwards `Last-Event-ID`, ignores duplicate/out-of-order sequences, refetches the canonical Recording snapshot after accepted events, and reconnects with bounded exponential backoff. If SSE is unavailable, the repository falls back to the canonical Recording GET. Recording Detail only holds the SSE subscription while foregrounded; backgrounding releases it and foregrounding reconnects from a fresh snapshot.

Artifact URLs are treated as short-lived capabilities. The app fetches the current artifact list, requests a new presigned URL for each Play/Download action, checks its expiry, and never persists the URL.

## Credits and billing API integration

Phase 13 replaces the production Credits and Billing mocks with authenticated API repositories while preserving mock implementations for tests/previews.

Credits use the frozen integer contract:

```text
GET /v1/credits/balance
GET /v1/credits/transactions
GET /v1/credits/reservations
GET /v1/pricing
```

The client never derives the final charge from pricing rules and never converts balances to floating point. Ledger and reservation cursors are consumed inside the repository. If pricing is not configured, the backend can return `503 SERVICE_UNAVAILABLE`; balance, transactions, and reservations still render while pricing is shown as unavailable.

Billing uses:

```text
GET  /v1/billing/packages
GET  /v1/billing/payment-orders
POST /v1/billing/payment-orders
GET  /v1/billing/payment-orders/{id}
POST /v1/billing/payment-orders/{id}/checkout
```

Create-order and checkout commands use UUID idempotency keys and retain the same key when retrying the same logical operation after transport failure. Checkout opens the provider externally and returns through `savestream:/billing/return?order_id=...`, registered on Android and iOS.

A browser/deep-link return is never considered proof of payment. The app reads/polls the payment order until the backend reports a terminal state, and only backend-confirmed `paid` invalidates/refetches Credits and Home balance state. Credit posting remains owned by verified backend webhook/reconciliation.

## Async state UX

Phase 14 standardizes async presentation without changing backend contracts. Data screens distinguish initial loading, refreshing, success, empty, recoverable error, non-recoverable error, and offline-like failure.

`SsAsyncErrorState` and `SsInlineAsyncError` derive retry behavior from typed failures such as `ApiException.retryable` and network/timeout categories. They never display raw exception text. When the backend supplies a request ID, it is rendered only as technical/support detail. Retry controls are omitted for non-retryable failures or when the UI does not retain a safe operation to replay.

`SsAsyncRefreshFrame` keeps already-rendered data on screen while a provider refreshes and adds a thin progress indicator. Recording pagination uses the same principle explicitly in `RecordingListState`: refresh and load-more failures remain inline so a transient request does not replace usable content with a full-screen error.

Initial loading remains screen-specific. Home, Channels, Channel Detail, Recordings, Recording Detail, Credits, Billing, Billing Return, and Profile use skeleton layouts close to their final structure. The only remaining `CircularProgressIndicator` in feature screens is the inline Recording Load More indicator.

## Accessibility, responsive, and performance

Phase 16 hardens the existing phone-first UI without changing backend contracts.

Accessibility improvements include semantic status labels, decorative avatar semantics exclusion, localized password-visibility tooltips, and a 48dp minimum touch target for shared text actions. Status meaning continues to be conveyed with text/icons in addition to color.

Responsive coverage now exercises 320x640, 390x844, and 430x932 phone viewports plus 2x text scaling. Narrow layouts use a compact Add Channel FAB, reduce bottom-navigation label density, stack status content instead of forcing it into ListTile trailing space, and allow timestamp/usage/status content to wrap without horizontal overflow. Tablet-specific polish remains deferred, but the shared layouts remain bounded instead of assuming a fixed phone width.

Performance audit results:

- long Channels and Recordings surfaces already use lazy list builders and cursor pagination;
- the mobile UI currently does not render remote images, so no unused image-cache layer is introduced;
- same-status Recording SSE progress updates now apply the structured event payload directly instead of performing a REST fetch for every progress event;
- status transitions, reconnects, and fallback paths still reconcile against the canonical Recording REST resource;
- existing startup/session restoration behavior is preserved with no new blocking startup work.

Phase 16 tests live in `test/accessibility_responsive_phase16_test.dart`, while the Recording realtime test also locks the reduced REST reconciliation frequency.

## Backend connectivity hardening

Production bootstrap now replaces the remaining Profile mock with `ApiProfileRepository` against authenticated `GET /v1/me`, so Auth, Profile, Watches, Recordings, Credits, and Billing all use the real backend repositories in a normal app launch.

Network policy is environment-scoped:

- Android release builds declare `INTERNET` permission in the main manifest.
- Android debug/profile builds allow cleartext traffic for local development only; release does not opt into cleartext HTTP.
- iOS allows local-network development without globally disabling App Transport Security.
- Local Android emulator builds default to `http://10.0.2.2:8000`.
- iOS simulator local development should pass `--dart-define=API_BASE_URL=http://localhost:8000`.
- Staging and production require an explicit HTTPS `API_BASE_URL`.

Example staging run:

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://api.example.com
```

The `Mobile Backend E2E` workflow boots the repository Docker E2E stack and runs Flutter repositories directly against the real API. Its smoke path covers register, verification, mobile login, `/v1/me`, Watch creation, billing checkout pending state, signed fake-payment confirmation, credit grant, Recording completion, artifact discovery/download URL, and cleanup. This test runs as a normal Flutter test on Linux and does not require an emulator.

## Automated test coverage

Phase 16 keeps the Phase 15 cumulative test pyramid and adds accessibility, constrained-layout, text-scaling, and realtime-frequency regression coverage.

Unit coverage includes DTO/domain decoding, typed API error mapping, Watch/Recording/payment status mapping, idempotency behavior, secure auth session/token rotation, and controller mutation/reconciliation behavior.

Widget coverage includes auth forms, Watch and Recording lifecycle variants, Credits/Billing states, theme/language switching, and loading/refresh/error/empty states.

Critical flow coverage runs the complete `SaveStreamApp` and router against controlled repository boundaries:

```text
launch -> onboarding -> login -> home
add channel -> channel detail
active recording -> stop -> stopped
billing -> pending -> paid
```

These critical-path tests intentionally live in the normal Flutter test suite so they run deterministically in CI without requiring an emulator. They cross screens, router state, provider state, and repository behavior while keeping external network/provider systems mocked or faked at the boundary.

## Validation

```bash
flutter gen-l10n
dart format --output=none --set-exit-if-changed \
  lib/app lib/core lib/features lib/l10n/l10n.dart test
flutter analyze --fatal-infos
flutter test
```

CI runs the same mobile checks for pull requests and for pushes to the long-lived `feat/flutter-mobile` branch.

Phase 8 settings validation additionally covers unverified profile fallback, all Theme options, VI/EN round-trip switching, Notifications/Privacy/Terms navigation, and Delete Account cancellation.


## Cloud recording and artifacts

The mobile app is a client for SaveStream cloud recording. It does not capture
livestream video on the phone and does not keep recording artifacts in app
storage. Recording jobs continue on backend infrastructure after the app is
closed.

Play / Download requests a fresh presigned artifact URL from the backend and
opens that URL through the platform/browser. The cloud recording artifact
remains authoritative.

Notification preferences now use the persisted backend preference API. Privacy
Policy and Terms of Use open the published documents at savestream.online.
