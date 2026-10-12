# SaveStream Production Admin and UX Audit

Date: 2026-10-12
Site: https://savestream.online
Environment: Production
Account scope: Authenticated Owner Admin session, with credentials entered by the owner directly in Chrome.
Testing policy: Read-only. No actual purchases, deletions, account suspensions, role changes, manual credit adjustments, recording starts/stops, or system setting changes.

## Coverage and result

- 26 authenticated routes checked at 1440px and 390px (52 route/viewport checks).
- 13 representative authenticated Admin/user routes checked at 320px.
- All 11 Admin sections were reachable on desktop and mobile.
- No confirmed global horizontal page overflow at 1440px, 390px or in the selected authenticated 320px routes.
- No broken visible images and no persistent JS/API errors across the 11 Admin sections during route sweeps.
- Admin System: API, Database, Redis, R2/object storage, and SMTP reached Healthy after data loaded. Initial Loading indicators were transient.
- Admin Users: search/apply/clear filters worked; existing results reappeared after clearing.
- Admin Payments: Orders, Stuck orders, Credit ledger, Manual minutes, and Stuck holds tabs opened without API errors.
- Admin Recordings: Recordings, Queue, Channels, LIVE detector, and Capacity tabs opened without API errors.
- Admin Overview: Refresh worked.
- Global search: search dialog opened and could be dismissed with Escape.
- User detail view opened successfully via a Users-list link.
- Help -> Admin navigation preserved authentication, including hard page reloads.
- Mobile Admin navigation drawer was verified to open after the app finished loading; no confirmed drawer regression.
- Settings / Notifications: three switches have associated HTML labels. A primitive selector-based accessibility warning was a false positive.
- Real-user account Overview, Channels, Recordings, Billing, Notifications, and Settings routes rendered for the Owner session.

## Confirmed UX or product issues

| ID | Priority | Finding | Reproduction / impact | Suggested change |
|---|---|---|---|---|
| UX-01 | P2 | Public landing page overflows at 320px. | At 320px on `/`, the sample browser URL strip and the `Start recording your own livestreams` CTA protrude about 18-26px beyond the viewport. Authenticated Admin 320px views did not show this problem. | Reduce hardcoded horizontal padding for the URL strip; allow CTA text to wrap and use a width-constrained button. Add 320px visual regression test. |
| UX-02 | P2 | Vietnamese localization is incomplete. | Choose VI. Some main marketing copy, pricing headings/details, and login page copy remain in English while surrounding navigation is Vietnamese. | Finish VI strings or clearly define which public pages are intentionally EN-only; test English <-> Vietnamese. |
| UX-03 | P2 (product availability) | Billing advertises packages and PayPal but checkout is not enabled. | `/billing` displays `Credit purchases are coming soon` and packages have disabled `Coming soon` buttons while another description invites the user to pay with PayPal. | Make text consistent with actual availability; activate PayPal only after payment readiness checks. This may be intentional launch gating rather than a code bug. |
| UX-04 | P3 | Mobile Admin Payments tab navigation is easy to overlook. | At 390px, the horizontal tab list cuts off `Manual minutes` and later tabs without a clear visible scroll hint. Tabs are functional when accessed. | Add edge fade/scroll indicators or a more explicit horizontally scrollable tab control. |
| UX-05 | P3 | `/status` redirects to `/help`. | Status visitors cannot see a dedicated public service-status/incident page. This is intentional in source, but it reduces operational discoverability. | Publish a real status page when status data is ready or change navigation/copy to clarify that status is not published. |
| UX-06 | P3 | Admin Overview status copy has singular/plural grammar issue. | The UI displayed `1 payment orders are stuck.` | Use singular/plural-aware copy. |

## Needs investigation; not consistently reproduced

| ID | Priority | Observation | Follow-up |
|---|---|---|---|
| AUTH-01 | P2 investigation | During a stress-like sequence of many full page reloads, mobile 390px `/overview` once redirected to `/sign-in` when `/v1/me` failed with a browser CORS `net::ERR_FAILED`. Subsequent mobile and desktop checks loaded `/overview` with 200 responses and retained the session. | Correlate Cloudflare WAF / bot / API response logs around the test. Verify that transient network errors do not destroy a valid session. Add a transient failure/retry browser regression test. Do not classify as a persistent logout bug without repetition. |

## Operational alerts (not UX defects)

- Admin Overview displayed one stuck payment-order alert.
- Admin Payments Stuck holds tab displayed a row.
- Admin Overview showed one recording error in the preceding 24 hours at the time of the test.
- Investigate these in operations/logs; this audit did not retry, modify or reconcile orders/recordings.

## Coverage limitations

- The Owner account's user-facing recording and channel lists had no usable media sample for a true watch/start/stop/play/download lifecycle test. Admin lists did load and expose data.
- Actual payments, refund capture, store billing, destructive actions, manual credit adjustments, admin privilege changes, runtime setting writes, account deletion, and TOTP step-up were deliberately not executed on production.
- Google/Apple OAuth opening was checked earlier, but this Owner Admin audit did not perform a full new-user OAuth login cycle.
- Search and filtering were exercised safely; not every individual combination of filter/date/sort/pagination values was covered.
- Screenshots were used locally to inspect layout and then removed from the test machine. This report contains no user personal data or credentials.

## Recommended next steps

1. Fix the confirmed UX-01/UX-02 P2 issues and clarify UX-03 purchase availability.
2. Add regression tests for small screens (320px, 390px), VI/EN localization, and authenticated Help -> Admin navigation.
3. Investigate intermittent AUTH-01 with server/Cloudflare logs without treating one unrepeatable automated error as conclusive.
4. Review the stuck payment order / hold and recent recording error in operations.
5. Use isolated test users and payment sandbox/internal app builds to run write-action and media-lifecycle E2E scenarios safely.
6. Rotate the Owner Admin password because it was previously pasted into chat; never store passwords in QA reports or repositories.

Result: Authenticated Admin read/navigation paths are broadly functional. No confirmed P0 defect was found in the read-only audit. Full transactional and destructive functional coverage is not yet demonstrated.

## Remediation update — 2026-10-12

The following code changes were completed after the read-only audit:

- [x] UX-01: constrained the sample browser URL and allowed the landing CTA to wrap at 320px.
- [x] UX-02: added Vietnamese strings for the high-visibility landing, pricing, authentication, and status content covered by this audit.
- [x] UX-03: removed the conflicting PayPal invitation while checkout is gated; Billing now describes packages as a preview until readiness checks pass.
- [x] UX-04: made the Admin Payments tabs explicitly horizontally scrollable on mobile and added a small-screen swipe hint.
- [x] UX-05: replaced the `/status` redirect with a truthful public status-information page, canonical metadata, footer navigation, and sitemap entry. It does not claim live health metrics that the product does not publish.
- [x] UX-06: corrected the singular/plural alert copy (`1 payment order is stuck`).
- [x] AUTH-01: production API logs confirmed one transient `429` for `/v1/me`. The web client now clears authentication only after a definitive `401/403`; network, rate-limit, and server failures preserve the session and retry with capped exponential backoff.
- [x] Added static regression coverage through `test:production-ux` and extended `test:auth` for transient-session handling.

Validation completed after the fixes:

- `npm run typecheck`
- `npm --workspace apps/web run test:auth`
- `npm --workspace apps/web run test:production-ux`
- `npm --workspace apps/web run test:p0`
- `npm --workspace apps/web run build`

Production operations were inspected without mutation:

- One PayPal order remains `pending` for more than 15 minutes and has a provider reference. It was not reconciled because doing so can change payment/credit state and requires explicit approval.
- The previously observed stuck credit hold is no longer present.
- The recent recording error was `STREAM_OFFLINE`, non-retryable, after two worker attempts; it appears consistent with the source stream ending rather than an infrastructure outage.

The Owner Admin password rotation remains a manual security follow-up and is not complete.
