# Google & Apple Sign-In for SaveStream (Web + Android + iOS)

**Status: implementation plan, not shipped.** Do not enable UI entry points until production providers, backend verification and end-to-end tests pass.

## Existing architecture
- Backend `IdentityService` manages SaveStream users, email/password, auth sessions, access/refresh tokens and one-time signup credits.
- Web `auth-context.tsx` maintains access tokens in memory and refresh via a secure HttpOnly cookie.
- Flutter `AuthRepository` and `AuthSessionManager` manage mobile tokens in secure storage.
- Mobile Firebase Core and Messaging are present, but Firebase Authentication/social sign-in are not integrated.

## Unified auth flow
1. Authenticate using Firebase Authentication Google or Apple provider on each client; fetch a fresh Firebase **ID token**.
2. Send `POST /v1/auth/social` with `{id_token, client_type: "web"|"mobile"}`.
3. Backend **verifies** Firebase signature, issuer, configured Firebase project audience, expiry, and provider. Never trust email or provider supplied separately by the client.
4. Resolve a persistent unique social identity by Firebase issuer and UID, with provider metadata stored server-side. Existing identities reuse the same `users.id` and all associated purchases, credits, watches and recordings.
5. For a first-time identity, create an account with verified email only if there is no existing account collision. **Never automatically link to an existing password account based only on a matching email.** Instead, prompt existing user to authenticate, then link with verified step-up.
6. Issue normal SaveStream access and refresh tokens with existing session rotation/revocation. Web refresh token stays in HttpOnly/Secure cookie; mobile stores returned refresh token securely.
7. Audit account creation/sign-in/link/unlink and rate-limit exchanges. Signup credits granted exactly once. Handle Apple private-relay email and unavailable name safely.

## Implementation work
- [ ] Backend verifier + settings: `SAVESTREAM_FIREBASE_AUTH_PROJECT_ID`, disabled until configured.
- [ ] Migration and ORM for social identity mapping with uniqueness and cascading deletion.
- [ ] Auth endpoints: token exchange, authenticated link and unlink, preventing removal of the last login method.
- [ ] Tests for forged/expired Firebase tokens, wrong issuer/audience, provider spoofing, replay/collision/concurrency, account linking, failed logins and credits.
- [ ] Web sign-in/sign-up Google and Apple buttons; Firebase web Auth SDK; exchange to existing SaveStream session; handle popup-blocked and redirect errors.
- [ ] Android Flutter buttons and Firebase Auth provider flows; Google OAuth clients and SHA-1/SHA-256.
- [ ] iOS Flutter buttons, Sign In with Apple capability, bundle IDs and Apple configuration.
- [ ] Web/iOS Apple Service ID + configured return URL and domain; Private Email Relay sender configuration.
- [ ] CI/browser/mobile integration tests, manual real device sign-in/sign-out, refresh, existing-account linking, purchases and deletion tests.

## Owner console configuration
- **Firebase Authentication**: enable Google and Apple providers on the same Firebase project configured for SaveStream.
- **Firebase / Google**: authorize actual web hostnames; configure Android package and SHA-1/SHA-256; register iOS bundle and OAuth clients as required.
- **Apple Developer**: enable Sign in with Apple on iOS App ID; configure Services ID, domain and redirect/return URL for web and Apple provider in Firebase.
- **Secrets**: do not paste or commit Apple private keys, service credentials or OAuth secrets. Store server secrets in deployment secret manager.

## Release acceptance
Google and Apple can each sign in on web, Android and iPhone. One identity maps to one SaveStream account across all clients. Existing email/password accounts cannot be taken over through email collision. Logged-in users can securely link an additional provider. Entitlements and credits remain unchanged. Token refresh, logout-all and account deletion still work.
