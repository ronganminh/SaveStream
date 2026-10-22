# Android v2 — Credits (Recording time) screens

App screenshots are rendered by `apps/mobile/test/screenshots/credits_screens_test.dart`
(real widgets and router, bundled Plus Jakarta Sans, 390×844 at 2×). The API, the Google Play
store and AdMob are fakes: no real purchase is made and no ad is loaded. Artboard renders come
from the design's `<name>.dc.html` files in headless Chromium at the same size.

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/credits flutter test test/screenshots/credits_screens_test.dart
```

On CI the Android emulator job also renders these screens
(`integration_test/credits_screenshots_test.dart`) and puts side-by-side sheets in the
`android-emulator-screens` artifact.

| Screen | App | Artboard |
| --- | --- | --- |
| ACredits | [ACredits.png](ACredits.png) | [ACredits.artboard.png](ACredits.artboard.png) |
| AUsageHistory | [AUsageHistory.png](AUsageHistory.png) | [AUsageHistory.artboard.png](AUsageHistory.artboard.png) |
| APurchases | [APurchases.png](APurchases.png) | [APurchases.artboard.png](APurchases.artboard.png) |
| APurchaseSuccess | [APurchaseSuccess.png](APurchaseSuccess.png) | [APurchaseSuccess.artboard.png](APurchaseSuccess.artboard.png) |
| APurchasePending | [APurchasePending.png](APurchasePending.png) | [APurchasePending.artboard.png](APurchasePending.artboard.png) |
| APurchaseFailed | [APurchaseFailed.png](APurchaseFailed.png) | [APurchaseFailed.artboard.png](APurchaseFailed.artboard.png) |
| ARestore | [ARestore.png](ARestore.png) | [ARestore.artboard.png](ARestore.artboard.png) |
| ARewardEarned | [ARewardEarned.png](ARewardEarned.png) | [ARewardEarned.artboard.png](ARewardEarned.artboard.png) |
| ARewardCooldown | [ARewardCooldown.png](ARewardCooldown.png) | [ARewardCooldown.artboard.png](ARewardCooldown.artboard.png) |
| ARewardLimit | [ARewardLimit.png](ARewardLimit.png) | [ARewardLimit.artboard.png](ARewardLimit.artboard.png) |
| ARewardFailed | [ARewardFailed.png](ARewardFailed.png) | [ARewardFailed.artboard.png](ARewardFailed.artboard.png) |
| AAdPrivacy | [AAdPrivacy.png](AAdPrivacy.png) | [AAdPrivacy.artboard.png](AAdPrivacy.artboard.png) |

## Routes

Recording time is `/usage` (full screen, no bottom bar). `/usage/cloud-hours` (the old "buy
cloud hours" link) redirects to it, so existing links (Home credits card and low/out banners,
channel "Buy minutes", the watch-limit and upsell sheets, notification routes that point at
`/usage`) open the new screen. Sub-screens: `/usage/history`, `/usage/purchases`,
`/usage/ad-privacy`, `/usage/purchase/success`, `/usage/purchase/pending`. Settings has
**Purchases & usage** and **Ad privacy choices** (the UMP "Privacy options" entry point).

## API and SDKs used

- Balance: `GET /v1/me/entitlement` (`cloud_minutes_available`, `ads`) and
  `GET /v1/credits/balance` (refund debt).
- Packs: `GET /v1/billing/packages` (name, minutes, `store_product_ids.google_play`, `featured`).
  Prices are only ever Google Play's `ProductDetails.price`; a pack Play doesn't return is not
  offered.
- Purchase: Play Billing via `in_app_purchase` with `obfuscatedAccountId = sha256(user id)`
  (user id from `GET /v1/me`), then `POST /v1/billing/store-purchases` (`transaction_id` = Play
  order id, or the purchase token when Play has none; `receipt` = purchase token; optional
  `price_amount_micros` / `price_currency_code` from Play's ProductDetails, display only). `credited` →
  the pack is consumed on the device and the success screen opens; `pending`/`payment_pending`
  (or Play's own PENDING) → Payment pending; Play errors → the failed dialog. Unconfirmed
  purchases stay in the durable retry queue.
- Restore: `restorePurchases()`; every owned, unconsumed pack is sent to the server (idempotent);
  the dialog lists the packs the server newly credited (`cloud_minutes_added > 0`), or says there
  was nothing to restore.
- Rewarded ad: `POST /v1/rewards` `{purpose: cloud_minutes, device_id: <install id>}` →
  `RewardedAd` with `ServerSideVerificationOptions(userId: ssv_user_id, customData:
  ssv_custom_data)` → poll `GET /v1/rewards/{id}` until `valid` (AdMob SSV reached the server),
  then refresh entitlement, balance and ledger. UMP consent is gathered before the first ad.
- Usage history: `GET /v1/credits/transactions` (last 14 days, up to 5 pages) with the ledger's
  `recording_channel_username` / `recording_duration_seconds` and `package_name` /
  `store_order_id`; older servers without them fall back to the user's recordings and
  `GET /v1/billing/payment-orders` + packages.
- Purchases & usage: `GET /v1/billing/payment-orders` filtered to `provider = google_play`
  (`store_order_id`, `client_price_amount_micros` / `client_price_currency`).

## Intentional differences

**Prices (all).** The artboards' `[PRICE]` is the Play-formatted price; screenshots use the
fake store's `$9.99 / $24.99 / $59.99`. The app never contains a price.

**Balance bar (ACredits and the dialogs behind it, and Home).** The bar compares the balance with
the entitlement's `cloud_minutes_cycle_total`. When the server sends none (no top-up yet, or an
older server) it shows only for the free trial (out of 10 minutes).

**Most popular.** The pack the server marks `featured`; none is marked when no pack is featured.

**Cooldown (ARewardCooldown).** The server has no cooldown between ads. The countdown is shown when
`POST /v1/rewards` answers 429, for `details.retry_after_seconds` (`RATE_LIMITED` and
`REWARD_LOCKED`); older servers: `locked_until`, else 5 minutes.

**Rewarded card states.** `REWARDED_ADS_UNAVAILABLE` (409) or `SERVICE_UNAVAILABLE` hides the card;
the daily cap (`REWARD_DAILY_CAP_REACHED` or `rewards_left_today = 0`) shows the limit line; an
unverified email shows "Verify your email to earn minutes from ads." (not drawn); a closed-early
ad goes back to idle; if verification takes longer than ~30 s a toast says the minutes will appear
shortly. The card is hidden when the build has no rewarded unit or the entitlement has no `ads`
block.

**Purchase failed.** When Play took the payment but the server could not confirm it, the dialog is
"We're still confirming your purchase" (not drawn) instead of "You weren't charged".

**Restore (ARestore).** "Nothing to restore" (not drawn) when Play has no unconsumed pack.

**Purchase success.** The Google Play order row is shown only for a `GPA.` order id (promo codes
have none).

**Usage history (AUsageHistory).** The chart sums recording charges per local day for 14 days; the
list shows every fetched ledger entry (the drawn "Free trial · Oct 2" is older than the chart).
The pack row shows the `GPA.` order id when the ledger has one (not for promo codes). A
recording's hold release is hidden when the recording was charged; an uncharged one is "Failed
recording · refunded · 0 min". On older servers, recordings no longer in the first page of the
list show "Recording" without the channel.

**Purchases (APurchases).** Rows show pack, hours, date, Play's order id (`store_order_id`) and
the Play price the app reported when it bought (`client_price_*`, formatted for the device
locale), and the status (Added / Pending / Refunded / Not completed). Orders without them (older
purchases, promo codes) show only what they have.

**Ad privacy (AAdPrivacy).** "Personalized ads" is stored on the device and **on by default** (the
owner's decision; the artboard draws it off); off sends non-personalized ad requests (npa=1). In
the EEA, UK and Switzerland UMP's consent answer governs. "Review privacy choices" (drawn as
"Review consent choices") opens the UMP privacy options form when UMP requires it (EEA/UK/
Switzerland, or a US state once the US-states message is published in AdMob); elsewhere a toast
says no form is needed.
The purchased note shows only for accounts with `has_purchased`.

**Banner (not drawn).** A 320×50 banner at the end of Home only when `ads.show_banners` (never
bought a pack) and a banner unit is configured; never on the player, purchase/payment or
verification screens. It can be added to the Recordings list later with the same `AdBannerSlot`.
