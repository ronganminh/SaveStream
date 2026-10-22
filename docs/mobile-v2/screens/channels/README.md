# Android v2 — Channels screens

App screenshots are rendered by `apps/mobile/test/screenshots/channels_screens_test.dart`
(real widgets and router, bundled Plus Jakarta Sans, 390×844 at 2×, fake repositories).
Artboard renders come from the design's `<name>.dc.html` files in headless Chromium at the same size.
`AAddChannel.artboard.png` is the first state of the clickable Add channel flow; its other
states are the static artboards below.

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/channels flutter test test/screenshots/channels_screens_test.dart
```

On CI the Android emulator job also renders these screens
(`integration_test/channels_screenshots_test.dart`) and puts side-by-side sheets in the
`android-emulator-screens` artifact.

| Screen | App | Artboard |
| --- | --- | --- |
| AChannels | [AChannels.png](AChannels.png) | [AChannels.artboard.png](AChannels.artboard.png) |
| AChannelsEmpty | [AChannelsEmpty.png](AChannelsEmpty.png) | [AChannelsEmpty.artboard.png](AChannelsEmpty.artboard.png) |
| AChannelsError | [AChannelsError.png](AChannelsError.png) | [AChannelsError.artboard.png](AChannelsError.artboard.png) |
| AAddSheet | [AAddSheet.png](AAddSheet.png) | [AAddSheet.artboard.png](AAddSheet.artboard.png) |
| AAddFound | [AAddFound.png](AAddFound.png) | [AAddFound.artboard.png](AAddFound.artboard.png) |
| AAddNotFound | [AAddNotFound.png](AAddNotFound.png) | [AAddNotFound.artboard.png](AAddNotFound.artboard.png) |
| AVerifyCode | [AVerifyCode.png](AVerifyCode.png) | [AVerifyCode.artboard.png](AVerifyCode.artboard.png) |
| AVerifyChecking | [AVerifyChecking.png](AVerifyChecking.png) | [AVerifyChecking.artboard.png](AVerifyChecking.artboard.png) |
| AVerifyNotYet | [AVerifyNotYet.png](AVerifyNotYet.png) | [AVerifyNotYet.artboard.png](AVerifyNotYet.artboard.png) |
| AVerifyExpired | [AVerifyExpired.png](AVerifyExpired.png) | [AVerifyExpired.artboard.png](AVerifyExpired.artboard.png) |
| AVerifyDone | [AVerifyDone.png](AVerifyDone.png) | [AVerifyDone.artboard.png](AVerifyDone.artboard.png) |
| AChannelRecording | [AChannelRecording.png](AChannelRecording.png) | [AChannelRecording.artboard.png](AChannelRecording.artboard.png) |
| AChannelWaiting | [AChannelWaiting.png](AChannelWaiting.png) | [AChannelWaiting.artboard.png](AChannelWaiting.artboard.png) |
| AChannelPaused | [AChannelPaused.png](AChannelPaused.png) | [AChannelPaused.artboard.png](AChannelPaused.artboard.png) |
| AChannelUnverified | [AChannelUnverified.png](AChannelUnverified.png) | [AChannelUnverified.artboard.png](AChannelUnverified.artboard.png) |
| AChannelRemove | [AChannelRemove.png](AChannelRemove.png) | [AChannelRemove.artboard.png](AChannelRemove.artboard.png) |

## API used

- List, detail, create, pause/resume, delete, auto-record and LIVE alerts: `/v1/watches`.
  A new channel is created with `owner_attested: true` (the ownership checkbox) and with
  auto-record and LIVE alerts off; both are switched on when the bio check succeeds.
- Profile lookup for "Is this your channel?": `POST /v1/live-status`.
- Verification: `POST /v1/watches/{id}/verification` (current or new code),
  `POST …/verification/check` (`verified` / `code_not_found` / `retry_later`),
  `GET …/verification` (the pending code shown on unverified rows, without creating one).
  "Expires in N min" counts down to the server's `expires_at`; a `VERIFICATION_EXPIRED`
  answer or a passed `expires_at` shows the expired state, and **Get a new code** asks the
  server again.

## Intentional differences

**Found card (AAddFound).** The API returns no follower count, so the line under the handle is
the profile's display name only (omitted when it equals the username). The ownership box starts
unticked; confirming without it shows an inline error.

**Not found (AAddNotFound).** `POST /v1/live-status` answers an unknown username with the same
`503 STREAM_UNAVAILABLE` as a TikTok outage, so both show "We couldn't find a public profile";
only a dropped connection shows "We couldn't reach TikTok just now".

**Code expiry (AVerify\*).** The artboard's "[CODE LIFETIME]" placeholder is "Expires in 30 min"
(from `expires_at`, default TTL 1800 s). A `retry_later` answer (checked too soon, or TikTok did
not return the bio) shows a warning with the server's `retry_after_seconds`.

**Verified (AVerifyDone).** The auto-record switch shows the channel's real setting after the app
turns it on; when the account can't auto-record (no minutes) it stays off with a note.

**Channel rows (AChannels).** Avatar colours come from a stable hash of the username, so they can
differ from the drawing. A long handle is truncated with an ellipsis instead of running under the
chip. The shell's "… is recording" bar is hidden on the Channels tab and channel screens, where the
recording already shows on the channel.

**Recording (AChannelRecording).** **Stop recording** stops the in-flight recording without a
confirmation dialog, as drawn. Recordings/Recorded totals are summed from the user's recordings
for this channel; "Last LIVE" is the server's `last_live_at`.

**LIVE · not recording (AChannelPaused).** No rewarded ads in this release, so **Watch an ad ·
+5 min** is left out. When auto-record is off, or the channel waits for a free cloud slot, the
banner says so instead of "You're out of minutes".

**Unverified (AChannelUnverified).** The copy says "We don't record unverified channels" (not
"watch or record"): the server still checks an unverified channel for LIVEs. Channels added before
verification existed show "Verify by <date> to keep recording" from `verification_due_at`.

**Not drawn.** A user-paused channel shows "Watching is paused" with **Resume watching**; ⋮ opens
Pause/Resume watching and Remove channel. Out of minutes while offline shows the Home "out of
minutes" banner. The old detail screen's queue position and "missed" notes are not in the v2
artboards and were dropped.
