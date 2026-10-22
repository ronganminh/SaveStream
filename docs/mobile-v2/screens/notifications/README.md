# Android v2 — Notifications screens

App screenshots are rendered by `apps/mobile/test/screenshots/notifications_screens_test.dart`
(real widgets and router, bundled Plus Jakarta Sans, 390×844 at 2×, ANotifPrefs at 390×900,
fake repositories). Artboard renders come from the design's `<name>.dc.html` files in headless
Chromium at the same size.

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/notifications flutter test test/screenshots/notifications_screens_test.dart
```

On CI the Android emulator job also renders these screens
(`integration_test/notifications_screenshots_test.dart`) and puts side-by-side sheets in the
`android-emulator-screens` artifact.

| Screen | App | Artboard |
| --- | --- | --- |
| ANotifications | [ANotifications.png](ANotifications.png) | [ANotifications.artboard.png](ANotifications.artboard.png) |
| ANotificationsEmpty | [ANotificationsEmpty.png](ANotificationsEmpty.png) | [ANotificationsEmpty.artboard.png](ANotificationsEmpty.artboard.png) |
| ANotificationsError (not drawn) | [ANotificationsError.png](ANotificationsError.png) | — |
| ANotifPrefs | [ANotifPrefs.png](ANotifPrefs.png) | [ANotifPrefs.artboard.png](ANotifPrefs.artboard.png) |

## Where they open

- **Inbox** (`/notifications`, full screen): the bell on Home and Channels (and the old
  header bell still used on Recordings/Settings). A push tapped without a resource also lands here.
- **Preferences** (`/settings/notifications`, full screen): Settings → Notifications. There is no
  v2 Account screen yet; this is the existing settings entry.

## API used

- `GET /v1/notifications?limit=50&cursor=…` — the list (newest first, "Load more" follows the
  cursor). Pull to refresh; the list is also refetched each time the inbox opens.
- `PATCH /v1/notifications/{id}` `{"read": true}` — tapping a row marks it read.
- `POST /v1/notifications/mark-all-read` — **Mark all read** (optimistic; the dots come back if
  the server refuses).
- `GET` / `PATCH /v1/me/notification-preferences` — the switches. Each switch saves at once
  (optimistic, restored with a snackbar on failure).
- Android `POST_NOTIFICATIONS`: the existing push service (`firebase_messaging`
  `getNotificationSettings`). **Open settings** calls a new `openNotificationSettings` method on the
  `savestream/push` channel (`Settings.ACTION_APP_NOTIFICATION_SETTINGS`, App info as fallback);
  the permission is read again when the app resumes. When the OS hasn't been asked yet, the banner
  offers **Turn on notifications** (the system prompt) instead.

## Rows → backend

Inbox rows (icon / tone / link):

| `type` | Title shown | Icon, tone | Tap opens |
| --- | --- | --- | --- |
| `creator_live` | Channel is LIVE | broadcast, pink | Channel detail (`resource_type: watch`) |
| `recording_started` | Recording started | broadcast, pink | Player (`recording`) |
| `recording_ready` | Recording ready | check, green | Player |
| `recording_failed` | Recording ended | alert, pink | Player |
| `recording_missed` | Missed a LIVE | alert, pink | Player |
| `credits_low`, `free_minutes_low` | Running low | clock, amber | Usage / minutes (`/usage`) |
| `cloud_minutes_exhausted` | Out of minutes | card, pink | Usage / minutes |
| `recording_expiring` | Expiring soon | download, amber | Player of that recording |
| `purchase_completed` | Minutes added | check, green | Usage / minutes |
| `channel_verification_needed` | Verify your channel | shield, amber | by resource |
| anything else (admin broadcasts, new kinds) | server title | bell, brand | by resource, else only marked read |

Preference rows (Push = the server's app-notification switch, which also decides whether the
event appears in this inbox; Email = the `email_*` switch):

| Row | Push | Email |
| --- | --- | --- |
| LIVE started | `creator_live` | `email_creator_live` |
| Recording started (added) | `recording_started` | — (no email for this event) |
| Recording ready | `recording_ready` | `email_recording_ready` |
| Failed or missed | `recording_failed` | `email_recording_failed` (also covers missed) |
| Running low | always on (locked) | `email_credits_low` |
| Out of minutes | always on (locked) | `email_credits_exhausted` |
| Expiring soon | `recording_expiring` | `email_recording_expiring` |
| Product news | one `marketing` switch drawn across both columns | |

When the server reports `email_supported: false` the email switches are disabled and the footnote
says no notification emails are sent.

## Intentional differences

**Titles and bodies (ANotifications).** The body is the server's text (English, as the backend
writes it, e.g. "@my_shop_live is LIVE now."), so it reads differently from the drawn copy
("Recording started in the cloud.", "“Weekend restock sale” · 1:39:02 is ready to watch.").
Titles of known kinds are localized in the app; `recording_failed` is "Recording ended" because the
server sends it for failed *and* stopped-early recordings. "Missed a LIVE" says why the server
missed it (no free cloud slot), not "while you were out of minutes".

**Expiring soon.** Tapping opens that recording's player (the notification names the recording)
rather than the Recordings "Expiring soon" filter, which the Recordings v2 screen does not take as a
route parameter on this branch. The server warns about 24 hours ahead, so the preference subtitle is
"About a day before deletion" instead of "3 days before deletion".

**Credits.** There is no v2 Credits screen yet; balance notices open the existing usage/minutes
screen (`/usage`).

**Mark all read** is shown only while something is unread (the empty artboard shows a blank
button).

**Preferences (ANotifPrefs).**
- An extra **Recording started** row: the server has a separate switch for it (no email).
- **Running low** / **Out of minutes** Push cells are locked on: the server always creates those
  notifications. "Running low" fires at an hour or less of cloud time (60 credits), so the subtitle
  is "An hour or less left", not "Under 30 minutes left".
- **Product news** has one switch across Push and Email: the server's single `marketing` flag
  gates admin marketing broadcasts on every channel (in-app, push, email). It defaults off.
- A footnote explains that turning Push off also hides the event from the inbox, and that balance
  notices and missed LIVEs always appear.
- Push switches stay enabled while Android notifications are off: they still control the inbox.
- **Open settings** is full width, as drawn.

**Unread dot on the bell.** The API has no unread-count endpoint, so the dot (Home, Channels)
comes from the loaded feed (the 50 newest notifications).

**Not drawn.** Loading shows skeleton rows; a load error shows "Couldn’t load notifications" with
Retry (ANotificationsError above); a failed "Load more" shows a line above the button; the
preferences screen shows a spinner, then an error with Retry.

## API gaps (backend unchanged)

- No unread-count endpoint (`GET /v1/notifications` has `unread_only` but no total).
- No push-only switch: the "push" preference also suppresses the in-app notification, so Push and
  "in this inbox" cannot be chosen separately.
- No push switch for `credits_low`, `cloud_minutes_exhausted`, `recording_missed` or
  `purchase_completed` (always delivered in the app and by push).
- No email for `recording_started`, `free_minutes_low` or `purchase_completed`.
- `marketing` is one flag for every channel (no Push/Email split for product news).
- `free_minutes_low` (legacy free *local* minutes) has a push switch but no v2 meaning; it is not
  shown.
- Notification titles/bodies are English server strings (no localization keys or structured
  fields such as recording title, duration or minutes left).
- `recording_expiring` warns ~24 h ahead (artboard: 3 days).
