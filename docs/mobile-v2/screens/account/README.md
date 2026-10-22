# Android v2 — Account screens

App screenshots are rendered by `apps/mobile/test/screenshots/account_screens_test.dart`
(real widgets and router, bundled Plus Jakarta Sans, at the artboard sizes at 2×). The API is
faked; nothing is sent. Artboard renders come from the design's `<name>.dc.html` files in headless
Chromium at the same size (AAccount 390×1180, AReport 390×1080, ADeleteAccount 390×900, the rest
390×844).

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/account flutter test test/screenshots/account_screens_test.dart
```

On CI the Android emulator job also renders these screens
(`integration_test/account_screenshots_test.dart`) and puts side-by-side sheets in the
`android-emulator-screens` artifact.

| Screen | App | Artboard |
| --- | --- | --- |
| AAccount | [AAccount.png](AAccount.png) | [AAccount.artboard.png](AAccount.artboard.png) |
| AProfile | [AProfile.png](AProfile.png) | [AProfile.artboard.png](AProfile.artboard.png) |
| AHelp | [AHelp.png](AHelp.png) | [AHelp.artboard.png](AHelp.artboard.png) |
| ALegal | [ALegal.png](ALegal.png) | [ALegal.artboard.png](ALegal.artboard.png) |
| AReport | [AReport.png](AReport.png) | [AReport.artboard.png](AReport.artboard.png) |
| AReportSent | [AReportSent.png](AReportSent.png) | [AReportSent.artboard.png](AReportSent.artboard.png) |
| ASignOut | [ASignOut.png](ASignOut.png) | [ASignOut.artboard.png](ASignOut.artboard.png) |
| ADeleteAccount | [ADeleteAccount.png](ADeleteAccount.png) | [ADeleteAccount.artboard.png](ADeleteAccount.artboard.png) |
| ADeleteDone | [ADeleteDone.png](ADeleteDone.png) | [ADeleteDone.artboard.png](ADeleteDone.artboard.png) |
| ASuspended | [ASuspended.png](ASuspended.png) | [ASuspended.artboard.png](ASuspended.artboard.png) |
| ATerminated | [ATerminated.png](ATerminated.png) | [ATerminated.artboard.png](ATerminated.artboard.png) |

Notification preferences, Purchases & usage and Ad privacy choices were built earlier
(`../notifications`, `../credits`); the Account tab links to them.

## Routes

The Account tab is `/settings` (bottom nav "Account" active). Its screens are full screen (no
bottom bar), as drawn: `/settings/profile`, `/settings/help`, `/settings/legal`,
`/settings/report` (+ `/settings/report/sent`), `/settings/delete`, `/settings/language`,
`/settings/theme`, and the existing `/settings/notifications`, `/usage`, `/usage/purchases`,
`/usage/ad-privacy`. Signed-out routes: `/auth/account-suspended`, `/auth/account-closed`,
`/auth/account-deleted`.

The v1 screens these replace are removed: Settings, Profile, Security & account, Signed-in devices
(it showed sample devices only), Help, Report issue (it never sent anything), Legal hub, the
in-app Terms/Privacy link pages and Responsible use. The player's "Report a problem" on a failed
recording now opens a mail to support with the recording id.

## API and SDKs used

- Account tab: `GET /v1/me` (name, email), `GET /v1/me/entitlement` (`cloud_minutes_available` →
  "12 h 40 min left"), the installed version from `package_info_plus`.
- Profile: `PATCH /v1/me {display_name}` on Save changes (unchanged → back). Password → the existing
  reset flow (`/auth/forgot?email=…` → `POST /v1/auth/forgot-password`), now reachable while signed in.
- Help center: articles open `https://savestream.online/help/<slug>` in the browser (slugs of the
  web help center: `add-a-channel`, `automatic-recording`, `credits-and-pricing`,
  `storage-and-downloads`, `recording-failed`); search filters the list on the device (every word
  in title or summary); "Still need help?" opens `mailto:support@savestream.online`.
- Legal: `/terms`, `/privacy`, `/acceptable-use`, `/copyright`, `/refund` on savestream.online in the
  browser; Open-source licences → Flutter's `showLicensePage` (bundled font licences included).
- Report: `POST /v1/public/reports` (`kind: abuse`, the endpoint of the web /report form; becomes a
  case in Admin → Safety). "Someone is recording my LIVE" and "Remove a recording of me" send
  `reporter_role: self`, "Something else" `other`; the category leads the description. The response
  `reference` (`SR-…`) is shown on Report received.
- Sign out: `DELETE /v1/me/devices/{install id}` (best effort, so pushes stop), then
  `POST /v1/auth/logout` and the local session is cleared.
- Delete account: the existing `DELETE /v1/me` (unchanged); the local session is cleared, then the
  app shows the confirmation signed out. Close → Sign in.
- Suspended / Closed: shown when sign-in (password or Google) fails with `ACCOUNT_SUSPENDED` /
  `ACCOUNT_TERMINATED`; `details.reason` and `details.reference` come from the server. Appeal by email
  → `mailto:support@…` with the reference; the policies open in the browser.

## API gaps (not faked)

- **Email change**: `PATCH /v1/me` has no email. The email field is read-only with a note.
- **Sign-in method**: `/v1/me` doesn't say whether the account has a password or uses Google. The app
  remembers how this device last signed in; a restored session from before this version shows the
  password row.
- **Report**: there is no authenticated report endpoint. The public one needs Turnstile when the
  server has `TURNSTILE_SECRET_KEY`; then it answers `CAPTCHA_FAILED`, and the app opens the web
  `/report?type=abuse` form in the browser with a toast instead of claiming it was sent. Copyright
  notices always continue on the web form (it collects the full notice the Copyright Policy needs).
- **Suspension while signed in**: an open session only gets `AUTH_SESSION_REVOKED` (the app's
  "session expired"), so Suspended/Closed appear at the next sign-in.

## Intentional differences

**Account tab (AAccount).** An "App" section (Language, Theme) follows the Account section: they are
not drawn but stay reachable (Vietnamese users depend on it). It pushes the version footer below
the 1180px frame; the test scrolls to it. Avatars of the signed-in user use the brand color pair.

**Profile (AProfile).** The email note reads "Your sign-in email can’t be changed in the app yet…"
instead of the verification line (see gaps). Google sign-in shows "Sign-in method · Signed in with
Google" without a Change button. The name field takes up to 160 characters (the server limit).

**Help center (AHelp).** No match shows "No articles match “…”." (not drawn).

**Report (AReport).** Choosing "Copyright infringement" replaces the fields with a note and the
button becomes "Continue on the web" (not drawn). Missing username/details and an invalid email show
inline errors; a failed send shows an error box with abuse@savestream.online.

**Report received (AReportSent).** The reference is the server's (`SR-` + 8 characters).

**Delete account (ADeleteAccount).** The remaining time is the live balance; `[ACCOUNT DELETION URL]` is
savestream.online/delete-account. The button stays disabled until DELETE is typed (any case).

**Suspended / Closed.** The body names the case reference when the server gives one; the drawn
"after a report that a channel was recorded without permission" is replaced by the server's reason on
its own line ("Reason: …"). "Sign out" returns to Sign in (sign-in was refused, so there is no
session).
