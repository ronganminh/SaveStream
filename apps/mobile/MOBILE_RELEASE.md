# SaveStream Mobile Release

## Release target

The first SaveStream V2 store release is **Android-only** by owner decision. iOS remains a compile-only regression target for this release: `ios-release-compile` must stay green, but a signed iOS archive, TestFlight run and iOS runtime claim are deferred.

C8 Firebase push is also deferred until the owner supplies the production Firebase project. This release must not claim production push delivery.

## Product model

SaveStream V2 supports cloud recording and local recording on the user's device.

- Cloud artifacts remain authoritative for cloud recordings.
- Local recordings stay in app-private device storage and are scoped to the source account/device.
- Native store purchases add cloud minutes only after backend verification.
- Free-plan ads use AdMob/UMP; paid users do not initialize ads.

## Production build

Production API default:

```text
https://api.savestream.online
```

Android production build:

```bash
flutter pub get --enforce-lockfile
bash tool/generate_native_assets.sh
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=APP_VERSION=2.0.0
```

Current Dart build inputs:

| Define | Production value | Notes |
| --- | --- | --- |
| `APP_ENV` | `production` | Required for production behavior. |
| `APP_VERSION` | `2.0.0` | Must match the semantic release version used by the minimum-version gate. |
| `API_BASE_URL` | optional | Defaults to `https://api.savestream.online`; override must be absolute HTTPS. |
| `PRIVACY_POLICY_URL` | optional | Defaults to `https://savestream.online/privacy`; override must be HTTPS. |
| `TERMS_OF_USE_URL` | optional | Defaults to `https://savestream.online/terms`; override must be HTTPS. |
| `ADMOB_BANNER_HOME_ANDROID` | production banner unit | Required for live Android Home ads; omitted values use Google test units. |
| `ADMOB_BANNER_WATCH_ANDROID` | production banner unit | Required for live Android Channels ads. |
| `ADMOB_BANNER_LIBRARY_ANDROID` | production banner unit | Required for live Android Recordings ads. |
| `ADMOB_REWARDED_ANDROID` | production rewarded unit | Required for live Android rewarded ads. |
| `ADMOB_BANNER_HOME_IOS` | future iOS banner unit | Retained for the deferred iOS release. |
| `ADMOB_BANNER_WATCH_IOS` | future iOS banner unit | Retained for the deferred iOS release. |
| `ADMOB_BANNER_LIBRARY_IOS` | future iOS banner unit | Retained for the deferred iOS release. |
| `ADMOB_REWARDED_IOS` | future iOS rewarded unit | Retained for the deferred iOS release. |

Do not add secrets through `--dart-define`.

Launcher icons and the native splash are generated from `assets/branding/savestream_mark.svg` and are not committed. Run `tool/generate_native_assets.sh` after cloning and whenever the brand mark changes. The script requires Python 3 and Cairo.

## Android signing

Never commit the keystore or passwords. Release Gradle reads:

```text
SAVESTREAM_ANDROID_KEYSTORE_PATH
SAVESTREAM_ANDROID_KEYSTORE_PASSWORD
SAVESTREAM_ANDROID_KEY_ALIAS
SAVESTREAM_ANDROID_KEY_PASSWORD
```

All four values are required for a publishable artifact. CI may compile an unsigned release bundle when they are absent, but that artifact is not for store upload.

AdMob application ID:

```text
SAVESTREAM_ADMOB_ANDROID_APP_ID
```

CI falls back to Google's official test app ID. Set the production Android AdMob app ID for release traffic.

## Native purchase verification (C6)

CI uses fake store/plugin behavior; it does not make a real Google Play/App Store transaction. Before release:

- load all production/test products and confirm localized prices come from the store;
- exercise purchased, pending, cancelled and failed paths;
- confirm the backend returns `credited` before the app completes the store transaction;
- lose network after store purchase, relaunch, reconnect and confirm durable retry without double credit;
- verify redelivery/restore remains idempotent;
- confirm entitlement, Channels and Home refresh after credit.

Record device/OS, store environment, product ID, non-secret transaction ID, backend result and final cloud-minute balance.

## Ads and consent verification (C7)

Free-plan ads use Google Mobile Ads with UMP consent.

Manual checks:

- Free account with zero followed creators: no UMP explanation/prompt and no ad request.
- Free account after the first creator: SaveStream explanation appears before UMP/system consent when required.
- Decline consent: no ad initialization/request.
- Paid/Pro account: no ad initialization.
- Home, Channels and Recordings banners collapse on no-fill.
- Rewarded flow sends backend `ssv_user_id` and `ssv_custom_data`; reward is granted only after backend status becomes valid.
- Production AdMob Privacy & messaging configuration matches the real app and target regions.

## iOS compile-only gate

The first release is Android-only. No iOS archive, certificate, Team ID, TestFlight run or real-device test is required for this release.

`ios-release-compile` compiles the production configuration for the iOS simulator. This proves shared Dart/native plugin code compiles; it does not prove signed iOS runtime behavior.

## Permission audit

Android main manifest currently declares only:

- `android.permission.INTERNET`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_DATA_SYNC`

It does **not** request broad shared-storage access, camera or microphone. Local recordings stay in app-private storage.

Because C8 is deferred, the Android manifest also does not request `POST_NOTIFICATIONS`. Add it only together with the production Firebase push implementation and permission UX.

iOS retains C7's `NSUserTrackingUsageDescription` for the deferred ads/ATT path, but no camera, microphone, photo-library, location or local-network privacy usage key is part of the current product.

Any new permission requires product justification, privacy/Data safety review and a release-document update.

## Android R8 / resource shrinking

Release builds enable R8 minification and resource shrinking using `android/app/proguard-rules.pro`.

App-owned manifest/Flutter entry points are kept explicitly; third-party plugins are expected to ship consumer rules. Before upload, install an AAB-derived minified build on a real Android device and smoke-test auth, local recording/recovery, playback/share, purchase and ads.

## Legal

Published production URLs:

```text
https://savestream.online/privacy
https://savestream.online/terms
```

The app opens these documents externally.

## Notifications

Mobile notification preferences use:

```text
GET   /v1/me/notification-preferences
PATCH /v1/me/notification-preferences
```

Notification preferences and in-app notification UX are implemented. Production Firebase push remains deferred to C8, so the Android store release must not claim push delivery until C8 is completed and tested.

## Store data declaration notes

Reconcile Google Play Data safety against the exact release commit. The current Android V2 release can process or collect:

- account identity and authentication/account-management data;
- app-scoped device identifier used for local-recording ownership/device registration;
- Watch/creator and local/cloud recording metadata;
- local recording files stored in app-private storage unless the user explicitly shares them;
- cloud recording artifacts and presigned playback/download access;
- native-store purchase product, transaction and receipt/verification data (C6);
- advertising identifiers/consent state and rewarded-ad verification metadata when Free-plan ads are enabled (C7);
- diagnostics/support request metadata submitted by the user.

C8 Firebase push is not included yet, so this release must not claim collection of a production Firebase push token or working push delivery. Revisit the declaration when C8 is merged.

Do not claim that SaveStream collects camera, microphone or broad shared-storage content: the current release does not request those permissions.

## Release checklist

- Mobile CI green on the exact release commit.
- Mobile Backend E2E green on the exact release commit.
- `pubspec.lock` committed and `flutter pub get --enforce-lockfile` succeeds.
- `pubspec.yaml` is `2.0.0+200`; any later upload uses a strictly higher build number.
- Android release is not using debug signing.
- Android signing secrets are installed outside Git.
- Native assets generate successfully from the official brand mark.
- Production API and legal URLs resolve over HTTPS.
- Native purchase sandbox checks pass.
- C7 consent/ad checks pass with production AdMob configuration.
- R8/minified Android release is smoke-tested on a real Android device.
- `ios-release-compile` is green; no iOS runtime/signing claim is made.
- C8/push is not claimed until Firebase implementation is complete.

## C3 Android local-recording final-device checks

Record model, Android version, battery/free-storage start/end, recorded duration and output file size for each run.

- Record for 10 minutes in foreground, then with screen locked.
- Switch apps while recording and confirm the foreground service remains active.
- Disconnect networking for 30 seconds, reconnect, and verify recording resumes without claiming disconnected time.
- Force-stop or kill the app during capture, relaunch, and verify recovery ends as recovered or partial.
- Reduce free storage below the product threshold and verify recording stops safely.
- Use notification Stop and verify finalization without opening the app.
- Sign out during an already granted lease and verify capture is not truncated solely because auth ended.
- Sign into another account and verify prior user's app-private files remain hidden; return to the original account and verify visibility.
- Check battery-optimization guidance and the system settings round-trip.
