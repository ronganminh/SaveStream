# SaveStream Mobile Release Checklist

This checklist covers the owner-operated steps that cannot be completed by CI or committed to Git.

## Store accounts and app records

- [ ] Google Play Console account is active.
- [ ] Android app record exists for package `com.savestream.app`.
- [ ] Apple Developer / App Store Connect setup is complete if iOS distribution is enabled later.
- [ ] Store contact, support URL, privacy URL and terms URL are current.

## Android signing and build

- [ ] Production keystore exists outside Git.
- [ ] `SAVESTREAM_ANDROID_KEYSTORE_PATH` is configured.
- [ ] `SAVESTREAM_ANDROID_KEYSTORE_PASSWORD` is configured.
- [ ] `SAVESTREAM_ANDROID_KEY_ALIAS` is configured.
- [ ] `SAVESTREAM_ANDROID_KEY_PASSWORD` is configured.
- [ ] Release AAB is built from an exact green commit.
- [ ] R8/minification and resource shrinking are enabled and the release bundle passes smoke testing.
- [ ] Version/build number is incremented for every uploaded store artifact.

## Firebase and push

- [ ] Real `android/app/google-services.json` is placed at build time and is not committed.
- [ ] Real `ios/Runner/GoogleService-Info.plist` is placed at build time when iOS is enabled and is not committed.
- [ ] Backend uses `SAVESTREAM_PUSH_PROVIDER=fcm`.
- [ ] Backend receives `SAVESTREAM_PUSH_FCM_SERVICE_ACCOUNT_JSON` from secret storage, not Git.
- [ ] Android Creator LIVE and Recording notification channels are verified on a device.
- [ ] Push permission, token refresh, foreground notification, and deep-link tap behavior are verified.
- [ ] APNs authentication key, Key ID and Team ID are configured in Firebase before iOS runtime push testing.

## In-app purchases

- [ ] Google Play one-time products exist for every SaveStream cloud-hours product ID.
- [ ] Product IDs exactly match backend/store configuration.
- [ ] Google Play license-test account can purchase, cancel and retry products.
- [ ] Pending purchase and network-retry flows are checked.
- [ ] Backend grants cloud hours only after store verification and does not double-credit replayed transactions.
- [ ] App Store Sandbox products are configured before iOS billing is released.

## Ads and consent

- [ ] AdMob account is active.
- [ ] Android app is registered in AdMob.
- [ ] Production banner/rewarded ad unit IDs are supplied via Dart defines.
- [ ] `SAVESTREAM_ADMOB_ANDROID_APP_ID` is supplied to the Android build.
- [ ] UMP privacy message is configured.
- [ ] Rewarded-ad server-side verification is configured against the production backend.
- [ ] Test devices/demo ad units are used for internal testing; production ads are not clicked by the development team.
- [ ] `app-ads.txt` and store listing ownership are configured before full production ad serving.

## Store privacy and policy declarations

- [ ] Declare account identifier/device identifier used for authenticated device registration.
- [ ] Declare FCM push token processing.
- [ ] Declare purchase history / transaction identifiers used for billing verification.
- [ ] Declare ad/consent data used by Google Mobile Ads and UMP.
- [ ] Declare diagnostics/support data actually collected by the app/backend.
- [ ] Confirm there is no undeclared background location, contacts, microphone, camera or media-library collection.
- [ ] Privacy Policy and Terms URLs are reachable from the production app and store listing.

## Final device checks

- [ ] Android onboarding, sign-in, add creator, local recording, cloud recording, playback/download, purchase and notifications work on a physical device.
- [ ] C3 local-recording scenarios in `apps/mobile/MOBILE_RELEASE.md` are completed and recorded.
- [ ] Free account creator limit is enforced.
- [ ] Paid entitlement and three concurrent cloud-slot behavior are verified.
- [ ] A fourth auto-record demand enters the waiting queue and FIFO promotion works.
- [ ] Account switching does not expose Local files owned by another account.
- [ ] App survives process restart with secure-session restoration.
- [ ] Release build has no debug menus, test API URL, demo signing key or production-secret file committed to Git.

## Release evidence

Record the release commit SHA, app version/build, AAB checksum, device/OS used for manual verification, purchase test evidence, push test evidence and final store-review notes.
