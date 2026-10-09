# SaveStream — App Store Cloud Hours: TestFlight and backend activation

## Status and safety

The Flutter app uses `in_app_purchase` / StoreKit 2 and calls `POST /v1/billing/store-purchases` with Apple's signed transaction JWS. The backend verifies the device JWS, independently asks Apple's App Store Server API for the same transaction, verifies Apple's server JWS, checks product + transaction identifiers, then grants cloud minutes once per store transaction. Fake or missing receipts never grant minutes.

**Do not switch the existing Google Play production payment provider to `live` until Apple In-App Purchases and an Apple In-App Purchase key are configured.** The normal Compose file remains Android-only. The optional `docker-compose.production.apple-store.yml` activates *both* store providers and provides the Apple credentials through Docker secrets. The overlay must be included on all subsequent production redeploys once Apple IAP is enabled.

## Apple App Store Connect: prerequisites (Account Holder)

1. Under **Business**, accept the **Paid Apps Agreement**, complete banking and tax details, and confirm the agreement is **Active**. Apple requires this even for sandbox testing.
2. Ensure an iOS app record for **SaveStream** exists with bundle ID `com.savestream.app`. Copy the **numeric Apple ID** of the app (not the Team ID `NW22NWLTK4`).
3. Under **SaveStream → Monetization → In-App Purchases**, create three **Consumable** products (not subscriptions):

   | Product ID | Reference/display name | Quantity credited by backend | Suggested US price |
   | --- | --- | --- | --- |
   | `savestream.hours.50` | SaveStream Cloud Hours — 50 | 3,000 cloud minutes | $9.99 |
   | `savestream.hours.150` | SaveStream Cloud Hours — 150 | 9,000 cloud minutes | $24.99 |
   | `savestream.hours.400` | SaveStream Cloud Hours — 400 | 24,000 cloud minutes | $59.99 |

   Add at least one localization (English name/description), availability, price and required review metadata. StoreKit displays each product's *localized App Store price* rather than the backend's USD price. The product IDs cannot be changed after creation. Changes can take up to an hour to show in sandbox.
4. Under **Users and Access → Integrations → In-App Purchase**, generate a dedicated **In-App Purchase** key. Retain its **Key ID**, **Issuer ID** and downloaded `SubscriptionKey_<KEY_ID>.p8` securely. This key is *different from* a Distribution certificate, APNs `.p8`, and the App Store Connect API Team key.
5. Configure App Store Server Notifications V2 (sandbox and, later, production) to `https://api.savestream.online/v1/webhooks/app-store`. The backend verifies Apple-signed `TEST` and other non-refund events and acknowledges them with HTTP 204 without changing a balance; it applies a balance reversal only for validated `REFUND` events.
6. Create an App Store Connect **Sandbox Apple Account** or install a TestFlight build for the eligible tester. TestFlight StoreKit purchases use **sandbox** transactions and do not charge real money.

## Secure VPS credentials (after items above exist)

The VPS currently keeps production non-secret settings in `~/SaveStream/deploy/vps/production.env`, and secret files under `SAVESTREAM_SECRETS_DIR`. Transfer `SubscriptionKey_<KEY_ID>.p8` to a secure location on the VPS (file mode `0600`) without pasting its contents into chat or Git. On the VPS, from the checked-out repository:

```bash
./deploy/vps/prepare-apple-store.sh /secure/path/SubscriptionKey_KEYID.p8 KEYID ISSUER_UUID NUMERIC_APPLE_ID sandbox
```

This command validates the private key, downloads the **three Apple root CA certificates** from Apple's official PKI site, constructs the base64-DER trust roots for `SignedDataVerifier`, stages the two Docker secrets, and backs up/updates the non-secret Apple identifiers in `production.env`. It **does not** switch traffic to Apple or restart the API.

With all Apple IAP product metadata ready, validate the opt-in production configuration (no container restart):

```bash
docker compose --env-file deploy/vps/production.env \
  -f deploy/vps/docker-compose.production.yml \
  -f deploy/vps/docker-compose.production.apple-store.yml config --quiet
```

Deploy only during an approved maintenance window, and include the Apple overlay on every later deployment. The overlay sets `SAVESTREAM_STORE_PURCHASE_PROVIDER=live` (Apple **and** Google Play), `SAVESTREAM_APP_STORE_ENVIRONMENT=sandbox` for TestFlight, and mounts both Apple secret files.

Do not use Apple's production environment for TestFlight receipts; when a public App Store version launches, plan explicit support for both production and sandbox testing or perform a controlled configuration migration (a sandbox-only verifier cannot validate live purchases).

## Real Sandbox acceptance test (cannot be simulated with fake unit tests)

1. Install the latest signed **TestFlight** build using bundle ID `com.savestream.app` and log into a dedicated SaveStream test account.
2. Open **Settings → Buy Cloud Hours**. Confirm that all three products and *non-empty, localized* prices appear. If missing, check Paid Apps Agreement, products' availability, metadata (allow propagation), and exact IDs.
3. Complete `savestream.hours.50` using sandbox/TestFlight. Check the app displays success only **after** the backend returns `credited`, and the account's cloud balance increases by **3,000 minutes**.
4. Confirm the production `payment_orders` record identifies provider `app_store` and has a unique Apple `provider_reference`; verify one `credit_ledger` grant only, without logging the full transaction JWS.
5. Retry the *same signed transaction* against `POST /v1/billing/store-purchases` as the same account: the API should return `credited`, `cloud_minutes_added = 0` and the existing balance (idempotency). Attempt with another account: reject the transaction, with no credit grant.
6. Check cancelled purchases do not grant credits; network interruptions retain a retry item and do not finish the Apple transaction until the server confirms credit.
7. Test 150h/400h using fresh sandbox purchases and confirm corresponding balance increases; test signed refund notifications separately before public release.

## Automated verification already available

- `backend/tests/test_v2_b5_store_purchases.py`: Apple JWS + App Store Server API adapter injection, idempotent credit, replay/ownership checks, cancelled/rejected purchases, refunds and Google Play regression coverage.
- `apps/mobile/test/v2c_c6_store_purchase_test.dart`: StoreKit adapter contract, backend receipt submission, pending/retry, and completion after verified credit.

Passing these tests does **not** establish a successful real Apple sandbox payment. Only the TestFlight flow above, with Apple products and an IAP key, can confirm that.

## References

- https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/
- https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/generate-keys-for-in-app-purchases/
- https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox
- https://github.com/apple/app-store-server-library-python
- https://www.apple.com/certificateauthority/
