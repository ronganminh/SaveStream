# QA bug status — report of 2026-10-14

Source: production QA report of 2026-10-14 (BUG-1 … BUG-12, owner account).
Fixes shipped in [#171](https://github.com/ronganminh/SaveStream/pull/171), merged to `main` as `8a19a03` and
deployed to production on 2026-10-14 (backend 09:41 UTC, web 09:44 UTC).

| Bug | Priority | Status | Where | Remaining |
| --- | --- | --- | --- | --- |
| BUG-1 "Recording" without a job | P0 | Fixed, deployed | #171 | — |
| BUG-2 Auto-record off despite credits | P0 | Fixed, deployed | #171 | Owner: re-grant with "Counts as purchase" to test auto-record |
| BUG-3 Failed jobs + CREATED date | P0 | Partly fixed | #171, this PR | Root cause of the failed `v_nenee` jobs: run Production Diagnostics |
| BUG-4 Checkout state / stuck order | P1 | Fixed, deployed | #171 | Confirm the stuck order expired (diagnostics) |
| BUG-5 App Store copy on /pricing | P1 | Fixed, deployed | #171; store copy removed entirely in #172 | — |
| BUG-6 Invalid handle stored | P1 | Fixed, deployed | #171 (migration 0022 ran) | Confirm the row is disabled (diagnostics) |
| BUG-7 Sample duration mismatch | P2 | Fixed, deployed | #171 | — |
| BUG-8 /channels empty state | P2 | Fixed, deployed | #171 | — |
| BUG-9 Overview copy | P2 | Fixed, deployed | #171 | — |
| BUG-10 Sign-in validation | P2 | Fixed, deployed | #171 | — |
| BUG-11 Slow "Restoring your session…" | P2 | Fixed, deployed | #171 | Signed-in users still wait for one refresh call |
| BUG-12 DAU = 0 | P2 | Explained, labeled | #171 | Admin/support/owner are excluded by design |

## Details

**BUG-1.** The web mapped "creator is live" straight to "Recording". The watch API now
returns `active_recording_id` / `active_recording_status`. A channel shows
"Recording" only for a queued/resolving/waiting_live/recording/stop_requested job.
A live channel without a job shows "LIVE – not recording" with the reason.
"View active recording" opens that job.

**BUG-2.** Auto-record requires a Pro account: a paid order or a grant marked
"Counts as purchase", plus a positive balance. The owner's 120-minute grant was not
marked, so the account stayed Free. That rule is kept. The changes:
- the admin form explains the option;
- the channel page has an Auto-record switch;
- the copy says how to enable it;
- manual grants resume credit-paused watches.

**BUG-3.**
- *CREATED date*: the data was right. `10/11/2026` (en-US, 11 October) read as
  November to a day-first reader. Admin tables now show `Oct 11, 2026, 08:50 PM`.
- *Error counters*: they use different windows. Overview is a rolling 24h snapshot
  refreshed hourly. Workers is a live window, default 15 min. Both are labeled, and
  Workers now ignores deleted rows.
- *Failed jobs*: still open. The failure reason was never shown in the UI.
  - This PR adds a Reason column (error code and message) to Admin → Jobs → Recordings.
  - It also adds a read-only **Production Diagnostics** workflow that prints failure
    reasons, recorder/worker error lines and cleanup checks.
  - The fix depends on what it reports.

**BUG-4.**
- `/v1/public/pricing` returns `checkout.{web,app_store,google_play}`; `/billing` and
  `/pricing` use it.
- Web checkout also stays behind `VITE_BILLING_CHECKOUT_ENABLED`, currently `false`.
- Reconciliation expires created/pending orders untouched for 24h unless PayPal reports
  them paid.

**BUG-6.**
- `POST /v1/watches` validates the TikTok handle with the web form's rule.
- Migration `0022_invalid_watch_sources` disabled existing invalid watches
  (`last_error = invalid_tiktok_source`) in production during the 09:41 UTC deploy.

**BUG-12.** DAU counts `role = user` sessions created or refreshed that UTC day.
Admin, support and owner accounts are excluded on purpose, and the card now says so.

## Test data still in production
- Channel `@p.c.dat25` on owner@savestream.online (monitoring).
- 120 manual minutes on owner@savestream.online.
