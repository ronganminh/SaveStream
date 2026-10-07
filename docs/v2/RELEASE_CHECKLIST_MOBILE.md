# SaveStream V2 — Mobile Release Checklist

**Release target:** Android V2. iOS remains compile-only for this release; do not claim signed iOS runtime/TestFlight support yet.

## 1. Code and CI gate

- [ ] C9 release PR is merged and the release SHA is recorded.
- [ ] `flutter-checks` is green on the exact release SHA.
- [ ] `android-emulator-smoke` is green on the exact release SHA.
- [ ] `Mobile Backend E2E` is green on the exact release SHA.
- [ ] `ios-release-compile` is green as a compile-only regression gate.
- [ ] `bash apps/mobile/tool/release_audit.sh` passes.
- [ ] `apps/mobile/pubspec.yaml` is `2.0.0+200` or a strictly higher build number for a subsequent upload.

## 2. Owner accounts and production credentials

- [ ] Google Play Console account is active and package ID is `com.savestream.app`.
- [ ] Play App Signing/upload-key recovery information is stored securely.
- [ ] Production Android keystore exists outside Git.
- [ ] Release environment contains:
  - `SAVESTREAM_ANDROID_KEYSTORE_PATH`
  - `SAVESTREAM_ANDROID_KEYSTORE_PASSWORD`
  - `SAVESTREAM_ANDROID_KEY_ALIAS`
  - `SAVESTREAM_ANDROID_KEY_PASSWORD`
- [ ] AdMob account/app is approved and `SAVESTREAM_ADMOB_ANDROID_APP_ID` is the production app ID.
- [ ] Production AdMob unit IDs are configured for Home, Channels, Recordings and rewarded ads.
- [ ] Google Play products matching `GET /v1/billing/packages` are created, active and available on the test/release track.
- [ ] Firebase is intentionally **not required for this release** because C8 is deferred. Do not claim push notifications until C8 is complete.

## 3. Production build inputs

- [ ] `APP_ENV=production`
- [ ] `APP_VERSION=2.0.0`
- [ ] `API_BASE_URL` is omitted to use `https://api.savestream.online` or is an approved HTTPS override.
- [ ] `PRIVACY_POLICY_URL` is omitted to use `https://savestream.online/privacy` or is an approved HTTPS override.
- [ ] `TERMS_OF_USE_URL` is omitted to use `https://savestream.online/terms` or is an approved HTTPS override.
- [ ] `ADMOB_BANNER_HOME_ANDROID`
- [ ] `ADMOB_BANNER_WATCH_ANDROID`
- [ ] `ADMOB_BANNER_LIBRARY_ANDROID`
- [ ] `ADMOB_REWARDED_ANDROID`
- [ ] No secret is supplied through `--dart-define`.

## 4. Android permission and R8 audit

Expected explicit permissions only:

- `android.permission.INTERNET`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_DATA_SYNC`

Before upload:

- [ ] No `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` or `MANAGE_EXTERNAL_STORAGE`.
- [ ] No `CAMERA` or `RECORD_AUDIO`.
- [ ] No `POST_NOTIFICATIONS` while C8 is deferred.
- [ ] R8 minification and resource shrinking are enabled for release.
- [ ] Release build starts successfully after shrinking.
- [ ] Auth, local recording, player/share, native purchase and ads still work on the minified build.

## 5. Local recording final-device checks

Run on at least one real Android device using the release/minified artifact:

- [ ] 10-minute foreground local recording.
- [ ] 10-minute recording with screen locked.
- [ ] Background/app-switch recording.
- [ ] 30-second network loss then recovery.
- [ ] Notification Stop action finalizes the file.
- [ ] Force-stop/crash then recovery of interrupted file.
- [ ] Low-storage stop without losing completed bytes.
- [ ] Sign-out does not truncate an already granted recording lease.
- [ ] A different account cannot see another user's app-private local files.
- [ ] Battery-optimization guidance opens the correct Android system screen and refreshes on return.

Record device model, Android version, battery/free-storage start/end, duration and output file size.

## 6. Native purchase checks (C6)

Using Google Play license testers:

- [ ] Store-localized prices are shown; no hard-coded production price is used.
- [ ] Purchased, pending, cancelled and failed paths are exercised.
- [ ] Backend verifies the transaction through `/v1/billing/store-purchases`.
- [ ] The app completes the store transaction only after backend status is `credited`.
- [ ] Lose network after store purchase, relaunch, reconnect and verify durable retry without double credit.
- [ ] Restore/redelivery remains idempotent.
- [ ] Entitlement, Channels and Home refresh after credit.

## 7. Ads and consent checks (C7)

- [ ] Production AdMob app/unit IDs are used; Google demo IDs are not used for production traffic.
- [ ] Free account with zero followed creators does not initialize ads or show consent UI.
- [ ] After the first followed creator, the SaveStream explanation appears before UMP/system consent when required.
- [ ] Consent decline does not initialize/request ads.
- [ ] Paid/Pro account never initializes ads.
- [ ] Home, Channels and Recordings banner slots collapse on no-fill.
- [ ] Rewarded SSV sends backend-provided `ssv_user_id` and `ssv_custom_data`; reward is granted only after backend status becomes valid.
- [ ] AdMob Privacy & messaging configuration matches the production app and target regions.

## 8. Backend/mobile contract checks

- [ ] New Free account reports 3 Watches and 0 concurrent cloud slots.
- [ ] Creating a fourth Free Watch returns `WATCH_LIMIT_REACHED`.
- [ ] Verified purchase changes entitlement to paid/Pro backend values.
- [ ] With all 3 paid cloud slots occupied, the next LIVE auto-record enters `waiting_for_cloud_slot` and exposes `queue_position`.
- [ ] Recording completes, artifact URL is generated and credit settlement is reflected.

These are exercised by **Mobile Backend E2E**; re-run manually only when investigating a release failure.

## 9. Data safety, privacy and store listing

Reconcile the exact release SHA with Google Play Data safety and the published privacy policy.

- [ ] Account/auth data declared correctly.
- [ ] App-scoped device identifier/device-registration data declared correctly.
- [ ] Watch/creator and recording metadata declared correctly.
- [ ] Purchase transaction/receipt verification data declared (C6).
- [ ] Advertising/consent/reward verification data declared (C7).
- [ ] Local recording files are described as app-private unless the user explicitly shares them.
- [ ] No camera/microphone/broad-storage collection is claimed because those permissions are absent.
- [ ] Push token/Firebase collection is **not** claimed because C8 is deferred.
- [ ] Privacy Policy and Terms URLs are public and reachable over HTTPS.
- [ ] Store copy does not promise iOS runtime or production push notifications.
- [ ] Third-party-content recording/download policy wording is reviewed before submission.

## 10. Final artifact and upload

```bash
cd apps/mobile
flutter pub get --enforce-lockfile
bash tool/generate_native_assets.sh
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=APP_VERSION=2.0.0 \
  --dart-define=ADMOB_BANNER_HOME_ANDROID=<production-id> \
  --dart-define=ADMOB_BANNER_WATCH_ANDROID=<production-id> \
  --dart-define=ADMOB_BANNER_LIBRARY_ANDROID=<production-id> \
  --dart-define=ADMOB_REWARDED_ANDROID=<production-id>
```

- [ ] AAB is signed with the production upload key, not a debug key.
- [ ] Install/test an AAB-derived minified build on a real Android device.
- [ ] Save release SHA, `versionName`, `versionCode`, Play track and uploaded artifact checksum in release evidence.
- [ ] If another artifact is uploaded later, increase the build number above `200`.
