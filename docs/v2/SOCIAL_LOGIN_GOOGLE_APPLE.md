# Google & Apple Sign-In for SaveStream (Web + Android + iOS)

**Status: implemented on draft PR #167; NOT merged, activated or production-tested.** Do not advertise social sign-in until platform configuration and complete CI/real-provider E2E tests pass.

## Existing architecture
- Backend `IdentityService` manages SaveStream users, email/password, auth sessions, access/refresh tokens and one-time signup credits.
- Web `auth-context.tsx` maintains access tokens in memory and refresh via a secure HttpOnly cookie.
- Flutter `AuthRepository` and `AuthSessionManager` manage mobile tokens in secure storage.
- Flutter now uses Firebase Authentication, Google Sign-In and Apple provider on the PR branch. Production provider credentials are not configured in code or deployed.

## Unified auth flow
1. Authenticate using Firebase Authentication Google or Apple provider on each client; fetch a fresh Firebase **ID token**.
2. Send `POST /v1/auth/social` with `{id_token, client_type: "web"|"mobile"}`.
3. Backend **verifies** Firebase signature, issuer, configured Firebase project audience, expiry, and provider. Never trust email or provider supplied separately by the client.
4. Resolve a persistent unique social identity by Firebase UID scoped to the configured Firebase project, with provider metadata stored server-side. Existing identities reuse the same `users.id` and all associated purchases, credits, watches and recordings.
5. For a first-time identity, create an account with verified email only if there is no existing account collision. **Never automatically link to an existing password account based only on a matching email.** Instead, prompt existing user to authenticate, then link with verified step-up.
6. Issue normal SaveStream access and refresh tokens with existing session rotation/revocation. Web refresh token stays in HttpOnly/Secure cookie; mobile stores returned refresh token securely.
7. Audit account creation/sign-in/link and rate-limit exchanges. Signup credits granted exactly once. Handle Apple private-relay email and unavailable name safely.

## Implementation work
- [x] Backend verifier + settings: `SAVESTREAM_FIREBASE_AUTH_PROJECT_ID`, disabled until configured.
- [x] Migration and ORM for social identity mapping with uniqueness and cascading deletion.
- [x] Auth endpoints: ID token exchange + password-confirmed linking. Unlinking is intentionally NOT exposed until a safe last-provider/password policy and UI exist.
- [~] Backend tests cover provider issuer rejection, disabled config, verified email, account collision, linking and credits; actual signed JWT/security cases, concurrency and production provider smoke remain release gates.
- [x] Web sign-in/sign-up buttons, Firebase SDK popup flows, SaveStream token exchange, collision and popup-blocked handling. Redirect fallback is NOT implemented; use modern browsers allowing popup login.
- [~] Android Flutter buttons/provider flow implemented. Google SHA-1/SHA-256 and updated Firebase config are required.
- [~] iOS Flutter buttons and Apple entitlements implemented. Apple Developer capability and Google URL scheme/client setup remain.
- [ ] Web/iOS Apple Service ID + configured return URL and domain; Private Email Relay sender configuration.
- [ ] CI/browser/mobile integration tests, manual real device sign-in/sign-out, refresh, existing-account linking, purchases and deletion tests.

## Owner console configuration
- **Firebase Authentication**: enable Google and Apple providers on the same Firebase project configured for SaveStream.
- **Firebase / Google**: authorize actual web hostnames; configure Android package and SHA-1/SHA-256; register iOS bundle and OAuth clients as required.
- **Apple Developer**: enable Sign in with Apple on iOS App ID; configure Services ID, domain and redirect/return URL for web and Apple provider in Firebase.
- **Secrets**: do not paste or commit Apple private keys, service credentials or OAuth secrets. Store server secrets in deployment secret manager.

## Release acceptance
Google and Apple can each sign in on web, Android and iPhone. One identity maps to one SaveStream account across all clients. Existing email/password accounts cannot be taken over through email collision. Logged-in users can securely link an additional provider. Entitlements and credits remain unchanged. Token refresh, logout-all and account deletion still work.

## Activation checklist (no new secrets in source control)

1. In Firebase Console > Build > Authentication > Sign-in method, enable **Google**. Add Apple after setting the Apple provider in Developer Portal.
2. In Firebase Console > Project settings, copy the public **web app** values to `apps/web` deployment environment: `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_APP_ID`. The buttons remain hidden on web until all are populated.
3. Set `SAVESTREAM_FIREBASE_AUTH_PROJECT_ID` in backend production environment to the **same** Firebase project ID used by web and mobile. Never configure this to an unknown project.
4. Register Android package `com.savestream.app` with release + debug signing SHA-1 and SHA-256 certificates. Download refreshed `google-services.json` after enabling Google Auth. Configure Google OAuth for iOS bundle `com.savestream.app`, update `GoogleService-Info.plist` and URL scheme as instructed by the current Google Sign-In iOS SDK.
5. In Apple Developer for SaveStream's existing iOS App ID, enable **Sign in with Apple**; configure Apple Services ID + associated website domain + Firebase callback URL for Apple in Firebase Authentication. Keep private .p8 signing keys in the secret store only.
6. In Firebase Authentication authorized domains, add the actual SaveStream web domain. For Apple's Hide My Email, configure outgoing email domain with Apple Private Email Relay.
7. Run latest flutter pub resolution to update `apps/mobile/pubspec.lock` and rerun CI. Temporary workflow `social-login-lockfile.yml` is PR-only and MUST be removed once the lockfile is generated.
8. Smoke test Google and Apple on production-hosted web, real Android/iPhone devices, then login across platforms with the SAME Firebase project/user identity. Include old-password account linking, account deletion, no duplicate grants, refresh and logout-all.

**Known limitations**: Apple and Google sign-in cannot function until their console credentials are enabled. Existing accounts are never linked by email alone. Firebase authentication provider-linking/unlinking UI for passwordless users and an OAuth redirect fallback are future enhancements, not part of this initial release.

## Activation status / requirements (2026-10-11)

Production runtime is NOT activated by merging this PR: Firebase Google and Apple
sign-in require additional owner console configuration.

- Existing local Firebase project in Android and iOS config is
  `savestream-d6684`. Existing Android configuration lacks OAuth clients,
  and the iOS configuration lacks Google CLIENT_ID and REVERSED_CLIENT_ID.
  Enable Google under Firebase Authentication then download both **new**
  platform config files. Do not reuse old config files.
- Configure Firebase Apple sign-in provider (Apple Services ID, Team ID,
  Key ID, and private key kept solely in console/secret store), Apple
  developer app ID capability, and appropriate Firebase redirect URL.
- Set `SAVESTREAM_FIREBASE_AUTH_PROJECT_ID=savestream-d6684` for production
  backend through the deployment environment **after** console settings
  and validation; the production compose now forwards this variable.
- Deploy the web Firebase PUBLIC configuration (four VITE_FIREBASE_* keys
  from Firebase web app configuration) through the frontend build environment.
  These values are project identifiers, not server OAuth secrets.
- Test new Google/Apple identities on all 3 clients against production API,
  plus collision linking, refresh, sign out, account deletion, credit purchase
  and a user who already owns saved recordings.
- Do not merge, publish a new mobile release, or enable social login
  on production based only on unit tests/CI; provider-console testing is
  a separate mandatory gate.
