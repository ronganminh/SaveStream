# Android v2 — Auth + Home screens

App screenshots are rendered by `apps/mobile/test/screenshots/auth_home_screens_test.dart`
(real widgets and router, bundled Plus Jakarta Sans, 390×844 at 2×, fake repositories).
Artboard renders come from the design's `<name>.dc.html` files in headless Chromium at the same size.

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/auth-home flutter test test/screenshots
```

| Screen | App | Artboard |
| --- | --- | --- |
| ASplash | [ASplash.png](ASplash.png) | [ASplash.artboard.png](ASplash.artboard.png) |
| AOnboard1 | [AOnboard1.png](AOnboard1.png) | [AOnboard1.artboard.png](AOnboard1.artboard.png) |
| AOnboard2 | [AOnboard2.png](AOnboard2.png) | [AOnboard2.artboard.png](AOnboard2.artboard.png) |
| AOnboard3 | [AOnboard3.png](AOnboard3.png) | [AOnboard3.artboard.png](AOnboard3.artboard.png) |
| ASignIn | [ASignIn.png](ASignIn.png) | [ASignIn.artboard.png](ASignIn.artboard.png) |
| ASignInError | [ASignInError.png](ASignInError.png) | [ASignInError.artboard.png](ASignInError.artboard.png) |
| ASignUp | [ASignUp.png](ASignUp.png) | [ASignUp.artboard.png](ASignUp.artboard.png) |
| ASignUpError | [ASignUpError.png](ASignUpError.png) | [ASignUpError.artboard.png](ASignUpError.artboard.png) |
| AForgot | [AForgot.png](AForgot.png) | [AForgot.artboard.png](AForgot.artboard.png) |
| AForgotSent | [AForgotSent.png](AForgotSent.png) | [AForgotSent.artboard.png](AForgotSent.artboard.png) |
| AReset | [AReset.png](AReset.png) | [AReset.artboard.png](AReset.artboard.png) |
| AResetDone | [AResetDone.png](AResetDone.png) | [AResetDone.artboard.png](AResetDone.artboard.png) |
| AVerifyEmail | [AVerifyEmail.png](AVerifyEmail.png) | [AVerifyEmail.artboard.png](AVerifyEmail.artboard.png) |
| AVerifyEmailError | [AVerifyEmailError.png](AVerifyEmailError.png) | [AVerifyEmailError.artboard.png](AVerifyEmailError.artboard.png) |
| AVerified | [AVerified.png](AVerified.png) | [AVerified.artboard.png](AVerified.artboard.png) |
| AGoogleLoading | [AGoogleLoading.png](AGoogleLoading.png) | [AGoogleLoading.artboard.png](AGoogleLoading.artboard.png) |
| AGoogleError | [AGoogleError.png](AGoogleError.png) | [AGoogleError.artboard.png](AGoogleError.artboard.png) |
| AHome | [AHome.png](AHome.png) | [AHome.artboard.png](AHome.artboard.png) |
| AHomeFirstRun | [AHomeFirstRun.png](AHomeFirstRun.png) | [AHomeFirstRun.artboard.png](AHomeFirstRun.artboard.png) |
| AHomeLive | [AHomeLive.png](AHomeLive.png) | [AHomeLive.artboard.png](AHomeLive.artboard.png) |
| AHomeLoading | [AHomeLoading.png](AHomeLoading.png) | [AHomeLoading.artboard.png](AHomeLoading.artboard.png) |
| AHomeLow | [AHomeLow.png](AHomeLow.png) | [AHomeLow.artboard.png](AHomeLow.artboard.png) |
| AHomeOut | [AHomeOut.png](AHomeOut.png) | [AHomeOut.artboard.png](AHomeOut.artboard.png) |

## Intentional differences

**Verify email (AVerifyEmail, AVerifyEmailError).** The backend verifies with the one-time
link token from the email (`POST /v1/auth/verify-email`, token of 16+ characters); there is no
6-digit code. The screen keeps the layout but says "We sent a verification link to … Open it on
this phone to finish.", the primary button is **Open email app** instead of **Verify email**, the
code boxes are left out, and the error reads "That link is wrong or expired. Request a new one."
The resend cooldown starts at 1:00 right after sign-up (the artboard shows it at 0:42).

**AVerified.** Verifying by link does not sign the user in, so both buttons lead to Sign in when
there is no session (and to Add channel / Home when there is).

**AForgotSent.** "It expires in 30 minutes" instead of "1 hour": the backend default
`ONE_TIME_TOKEN_TTL_SECONDS` is 1800.

**AReset.** A missing or expired reset token shows an error banner with **Request a new link**.

**Sign up.** Google sign-up also needs the consent box ticked first and sends the same consent.
The old screen's name field is gone, as drawn.

**Low / out of minutes (AHomeLow, AHomeOut).** No rewarded ads in this release, so the
**Watch an ad** buttons and "or watch an ad for 5 more minutes" are left out; the low banner says
"Buy a pack to keep recording." The native ad slot on AHome / AHomeLow is left out too.

**AHome credits card.** Purchased minutes show "Purchased minutes · billed per started minute"
and no progress bar: the API has no pack name ("Standard pack") and no total to measure against.
Trial minutes keep the bar (out of 10) and the drawn captions.

**Channel rows and recordings.** The "· 1 h 39 min" last-LIVE duration is left out; recording
tiles show the creator's display name (the API has no LIVE title) over a gradient placeholder
(no thumbnail yet). Avatar colours come from a stable hash of the username, so they can differ
from the drawing.

**Navigation.** The fourth tab is labelled **Account** as drawn and opens the existing Settings.

**Onboarding.** The language/theme toggles and legal links of the old welcome screen are gone (not
drawn); the legal links live in the sign-up consent text.

**Not drawn.** Continue with Apple appears on iOS only. A Home load error shows a card with
**Try again**. A store refund debt (`refund_debt` from `/v1/credits/balance`) turns the card red
with its own banner.

The artboards' CSS boxes are mostly content-box; spacing was matched by eye from these renders,
so a few elements sit a couple of pixels off.
