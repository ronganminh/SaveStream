# Android v2 — Recordings + Player screens

App screenshots are rendered by `apps/mobile/test/screenshots/recordings_screens_test.dart`
(real widgets and router, bundled Plus Jakarta Sans, 390×844 at 2×, fake repositories).
`ARecordings` is drawn as the whole scrolled list (390×1180), so both its app PNG and its
artboard render use that size. Artboard renders come from the design's `<name>.dc.html` files in
headless Chromium. Video playback is never started in the tests: the player shows its poster
until **Play** is tapped.

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/recordings flutter test test/screenshots/recordings_screens_test.dart
```

On CI the Android emulator job also renders these screens
(`integration_test/recordings_screenshots_test.dart`) and puts side-by-side sheets in the
`android-emulator-screens` artifact.

| Screen | App | Artboard |
| --- | --- | --- |
| ARecordings | [ARecordings.png](ARecordings.png) | [ARecordings.artboard.png](ARecordings.artboard.png) |
| ARecordingsEmpty | [ARecordingsEmpty.png](ARecordingsEmpty.png) | [ARecordingsEmpty.artboard.png](ARecordingsEmpty.artboard.png) |
| ARecordingsLoading | [ARecordingsLoading.png](ARecordingsLoading.png) | [ARecordingsLoading.artboard.png](ARecordingsLoading.artboard.png) |
| ARecordingsProcessing | [ARecordingsProcessing.png](ARecordingsProcessing.png) | [ARecordingsProcessing.artboard.png](ARecordingsProcessing.artboard.png) |
| ARecordingsFailed | [ARecordingsFailed.png](ARecordingsFailed.png) | [ARecordingsFailed.artboard.png](ARecordingsFailed.artboard.png) |
| ARecordingsExpiring | [ARecordingsExpiring.png](ARecordingsExpiring.png) | [ARecordingsExpiring.artboard.png](ARecordingsExpiring.artboard.png) |
| APlayer | [APlayer.png](APlayer.png) | [APlayer.artboard.png](APlayer.artboard.png) |
| APlayerSaving | [APlayerSaving.png](APlayerSaving.png) | [APlayerSaving.artboard.png](APlayerSaving.artboard.png) |
| APlayerSaved | [APlayerSaved.png](APlayerSaved.png) | [APlayerSaved.artboard.png](APlayerSaved.artboard.png) |
| APlayerDelete | [APlayerDelete.png](APlayerDelete.png) | [APlayerDelete.artboard.png](APlayerDelete.artboard.png) |
| APlayerProcessing | [APlayerProcessing.png](APlayerProcessing.png) | [APlayerProcessing.artboard.png](APlayerProcessing.artboard.png) |
| APlayerFailed | [APlayerFailed.png](APlayerFailed.png) | [APlayerFailed.artboard.png](APlayerFailed.artboard.png) |
| APlayerShared | not built (no share endpoint) | [APlayerShared.artboard.png](APlayerShared.artboard.png) |

## API used

- Library: `GET /v1/recordings` (all pages). The API filters by one status at a time, so the
  All / Recording / Processing / Failed / Expiring soon chips and the search filter on the device.
- Thumbnails: `thumbnail_url` on each recording; the artboard gradient shows until it loads, when
  it fails, or when the server has none yet.
- Player: `GET /v1/recordings/{id}` (plus the SSE stream while the recording is still active),
  `GET /v1/recordings/{id}/artifacts` (size, and `width`/`height` for "1080p") and
  `POST /v1/artifacts/{id}/download-url` for playback and Save to device.
- Retention: "Kept for N more days" and the "N days left" chips count down to the server's
  `expires_at`; nothing is computed from a retention period on the device. "Expiring soon" means
  `expires_at` within 3 days.
- Failures: "Why" is the server's `error.message` (or, for `missed_no_cloud_slot`, that no cloud
  slot was free); "N min charged" is `minutes_charged`. "What to do" is picked from `error.code`
  (`STREAM_*`: short LIVEs may not be captured; `SERVICE_UNAVAILABLE`: our side) and left out for
  other codes.
- Delete: `DELETE /v1/recordings/{id}`.

## Intentional differences

**Titles (all screens).** The API has no LIVE title yet (accepted by QA), so the handle is the
title and the line under it is the date (library) or date, time and length (player). The REC card
reads "@handle · LIVE now".

**Processing (ARecordings, ARecordingsProcessing, APlayerProcessing).** The API has no processing
progress or ETA, so the cards say "Processing…" without a percentage or bar and the subtitle is
the date instead of "ready in ~3 min". The player says "usually under 10 minutes". A finished
recording whose video file is not ready yet (`playback_ready: false`) is shown as processing.

**Share link (APlayer, APlayerShared).** There is no share-link endpoint, so **Share link** and its
sheet are left out and **Save to device** is full width. The processing banner drops "and sharing".

**Retry processing (ARecordingsFailed).** There is no endpoint to re-process a failed recording,
so the button is left out.

**Saving / saved (APlayerSaving, APlayerSaved).** The video is saved into the app's own storage
(the existing v1 download, resumable), not `Downloads/SaveStream`, and the download runs only
while the app is open; the copy says so ("Saved on this device", "keep the app open until it
finishes"). **Cancel** stops the download (the part already fetched is kept for a later resume).
**Open** and **Play saved copy** play the saved file in the full-screen player.

**Delete (APlayerDelete).** Deleting also removes the copy saved in the app (it lives in app
storage), so the body says that instead of "Copies you saved to your device aren't affected".

**Player progress (APlayer).** Before playback starts the bar is at 0:00:00; the artboard shows a
position mid-video. Playback is inline in the 440 px area (tap to pause, drag or tap the bar to
seek).

**Filter chips (ARecordingsFailed, ARecordingsExpiring).** The chip row scrolls horizontally, so
after tapping "Expiring soon" (or Failed) the row is scrolled to show it.

**Recording card (ARecordings).** Tapping a recording in progress opens its channel (timer and
Stop recording), as linked in the design; a recording without a channel opens its player, which
shows the timer and **Stop recording**. The shell's "… is recording" bar is hidden on the
Recordings tab, where the REC card already shows it.

**Not drawn.** Search (the magnifier) turns the title bar into a search field that filters by
channel. A recording still waiting for its LIVE shows a "Starting" chip. A recording past
`expires_at` shows "Expired" and can't be played. There are no ads on the player screens.
