# SaveStream Mobile

Flutter mobile client for SaveStream.

## Current milestone

Phase 11 includes:

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
- Credits / Usage screen with backend-aligned posted, reserved, and available balances;
- low-credit explanation, recording usage totals, recent credit transactions, empty/loading/error states, and pull-to-refresh;
- Billing screen with credit packages, recommended package treatment, recent payment orders, and buy CTA;
- payment order status coverage for pending, paid, failed, cancelled, and expired;
- mock checkout flow that creates pending orders and only transitions to paid after a repository status refetch, matching the backend-confirmation rule;
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
- Phase 11 tests cover status mapping, creator fallback, cursor pagination, create/mutation payloads, 404 handling, 402 handling, malformed status rejection, and failed-mutation reconciliation.

Authentication and Channels/Watch management now use real backend APIs in production bootstrap while their mock implementations remain available for tests/previews. Home consumes the real Watch repository for monitored-channel data; Recordings, Credits/Usage, Billing, and Profile keep their current mock repositories until their later integration phases.

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

Local environment defaults to:

```text
APP_ENV=local
API_BASE_URL=http://10.0.2.2:8000
```

Override build configuration with Dart defines:

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://api-staging.example.com
```

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

Other feature screen
  -> Riverpod provider/controller
  -> Repository interface
  -> Mock repository (until later phases)

MaterialApp.router
  -> guards
  -> StatefulShellRoute
  -> four preserved tab stacks
```

Repository boundaries remain intact: Watch has moved from `MockWatchRepository` to `ApiWatchRepository` in production without moving raw HTTP into presentation code, and the remaining mock-backed features can follow the same pattern.

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

Phase 9 remains the shared transport/error foundation. Phase 10 consumes it for real authentication, and Phase 11 consumes the authenticated client for real Watch/Channel data. Recording, Credits, Billing, and other feature repository migrations remain scoped to later phases.

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
