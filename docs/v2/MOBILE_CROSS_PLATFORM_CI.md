# SaveStream — Android / iOS functional CI coverage

## CI checks on every mobile pull request

The `Mobile CI` workflow runs three independent jobs (plus the existing
`Mobile Backend E2E` workflow whenever mobile/backend changes):

| Gate | Environment | What it proves |
|---|---|---|
| `flutter-checks` | GitHub Ubuntu | Format, Flutter Analyze, complete Dart unit/widget suite **with LCOV**, release Android App Bundle compile, release audit |
| `android-emulator-smoke` | Pixel 6 Android Emulator (API 35) | Install/launch actual Android Flutter app with safe CI Firebase placeholders; check process/crash logs; run Flutter `integration_test` on Android engine |
| `ios-release-compile` | GitHub macOS iPhone Simulator | Build native iOS app with production compile-time env + test-only Firebase config; run Flutter `integration_test` on iOS engine (no signing secrets) |
| `mobile-backend-e2e` | Docker/backend + Flutter HTTP test | Real API and database fixtures for auth, watch, billing/credits, invariants; no external storefront or ad network |

The Android/iOS `integration_test/native_journeys_test.dart` runs the same
functional flows in both OS engines. The CI environment uses **fake auth,
recordings, store and ads services**, preventing real charges/ad impressions.
Screens, route redirects, Flutter platform adapters, native plugin registrations
and UI user interactions still execute in their OS runtime.

### Device-level functional journeys

1. Onboarding -> sign in -> authenticated Home.
2. Watching -> add creator -> creator detail and notification controls.
3. Cloud Recordings -> active detail -> stop confirmation -> stop requested.
4. Settings -> change language EN to VI -> switch to dark theme.
5. Cloud Hours -> 50h/150h/400h localized offer prices -> fake purchase ->
   fake backend verifies/credits -> finish transaction, with platform-specific
   `app_store` or `google_play` mapping.
6. Rewarded-ad 10-minute offer and enforce daily rewarded limit in native UI;
   existing controller tests require verified SSV before an extension.
7. Actual native media decoding: download the project's 8-second H.264/AAC
   MP4 through a CI-local HTTP server, open it with SaveStream's `video_player`
   screen on Android/iOS, and verify Play/Pause plus advancing timeline.
8. **Android only**: capture a generated FLV byte stream from the CI host using
   the production `LocalRecordingService` foreground worker, verify a persisted
   FLV header and sidecar, then initialize native ExoPlayer on the **recorded
   file itself**. iOS local recording is not implemented; this test is skipped.
9. AdMob plugin initialization plus sample banner/rewarded ad loading (Google's
   official **test** units only), with SSV metadata setup but no ad impression;
   results are saved to `build/ci/*-admob-network.txt` and are non-gating
   because Google's test inventory/network can be unavailable.

The backend E2E stack also uses a generated FLV test livestream, records it
with production FFmpeg workers, debits the ledger, uploads to object storage,
downloads the MP4 and now invokes `ffprobe` and `ffmpeg` to validate duration,
codec and decode an actual frame. No real creator/network credential is needed.

The existing Dart test suite additionally covers profile/security/password
reset, notification preferences, rewards/SSV/consent, local-recording lease/
recovery/storage (including second slot), player/share/download behavior,
credit accounting, retries, billing cancellation/pending/duplicate transactions,
Free/Pro entitlements and accessibility. The backend CI and E2E own API/DB
verification and idempotency tests.

### Testing boundaries (important)

CI on public GitHub runners **does not** confirm all device-/provider-specific
behavior. These need a separate real-device / sandbox test lane:

- **Apple TestFlight StoreKit** consumables: purchase/cancel/restore, real signed
  JWS, backend credit `+3000/+9000/+24000` minutes and replay `+0`. Test using
  a dedicated sandbox Apple account; TestFlight Sandbox has no real charge.
- **Google Play internal testing**: licensed tester, Play Billing purchase and
  consumption, Real-time Developer Notifications and refunds.
- **AdMob**: test-device-only ads, real rewarded fullscreen callback, genuine
  Google SSV and UMP consent in applicable regions. CI performs native test-ad
  loading and exercises reward/UI/SSV logic in deterministic tests; it cannot
  honestly mark external SSV-to-VPS callbacks as verified without a trusted
  physical test device and actual reward playback. Never click production ads
  from automated tests.
- **Physical devices**: actual TikTok capture, Android foreground/background
  recorder, screen off and OEM battery optimizations, notifications/APNs/FCM,
  local storage and share sheet, Wi-Fi/cellular failures, and iOS background
  limitations. iOS native local recording is not yet implemented and should
  not be reported as covered.

Do **not** inject Apple `.p8`, Google Play service account, App Store certificate,
AdMob production IDs or any live API token into public fork PR workflows.
Real-store sandbox tests must be gated to trusted branches/device farm runners,
using masked secrets and isolated test accounts. This is **not** added to this
PR without user-approved infrastructure.

### Run locally

```bash
cd apps/mobile
flutter pub get --enforce-lockfile
bash tool/generate_firebase_ci_config.sh
bash tool/generate_native_assets.sh
flutter test --coverage
# Boot an Android emulator first (requires SDK/JDK):
bash tool/android_emulator_functional.sh
# Or macOS with Xcode + an installed, bootable iOS Simulator:
bash tool/ios_simulator_functional.sh
```

`android_emulator_functional.sh` includes the real Android launch smoke check.
The scripts also require FFmpeg on Android runners and create a temporary
`build/ci/ci-stream.flv` from `apps/web/public/samples/video-01.mp4`. The
CI-local media server (`tool/ci_media_server.py`) serves only fixed test paths.
The scripts retain `build/ci/*` logs and screenshots after failures. On GitHub,
workflow failures upload these as diagnostic artifacts for seven days. LCOV
is uploaded on every Flutter unit/widget run.

Use the `workflow_dispatch` button on GitHub Actions -> Mobile CI to rerun all
jobs for a specific branch. PR checks are intended as a merge gate: don't
mark cross-platform functionality complete while either simulator job is red.
