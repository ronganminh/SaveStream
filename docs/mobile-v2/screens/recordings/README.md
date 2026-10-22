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

**Saving / saved (APlayerSaving, APlayerSaved).** As drawn, **Save to device** puts the video in
the public **Downloads/SaveStream** folder and the toast says "Saved to Downloads". The video first
downloads into a resumable file in the app's cache (the v1 download), then the Android host
(`MainActivity` → `SaveStreamDownloads.kt`, channel `savestream/downloads`) copies it into
`MediaStore.Downloads` with `RELATIVE_PATH = Download/SaveStream` and `IS_PENDING = 1` while
writing, clears `IS_PENDING`, and the cache file is deleted. Android 10+ needs no storage
permission for this, and the manifest asks for none (no `READ_/WRITE_EXTERNAL_STORAGE`, no
`MANAGE_EXTERNAL_STORAGE`; no plugin in use adds them). The file is named
`SaveStream_<recording id>.mp4`; when the player opens it looks the name up in MediaStore, so a
copy the user has since deleted or moved shows **Save to device** again. The download runs only
while the app is open, so the panel still says "keep the app open until it finishes".
**Cancel** stops the download (the part already fetched stays in the cache for a later resume).
**Open** and **Play saved copy** play the saved file (its `content://` URI) in the full-screen
player.

*Android 7–9 (minSdk 24).* There is no permission-free way to write to the public Downloads folder
before Android 10, and the app does not ask for storage permission. The same flow and copy are
used, but the file goes to the app-specific `getExternalFilesDir(DIRECTORY_DOWNLOADS)/SaveStream`
(`Android/data/com.savestream.app/files/Download/SaveStream`), which needs no permission, is
visible over USB and in file managers, and is removed if the app is uninstalled.

*iOS.* Unchanged: the copy stays in the app's own storage, and the copy reads "Saving to your
device…" / "Saved on this device".

**Delete (APlayerDelete).** Deleting removes only the cloud recording. A copy saved to the device
belongs to the user and is never deleted by the app, so the body says "Copies you saved to your
device aren’t affected", as drawn.

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
