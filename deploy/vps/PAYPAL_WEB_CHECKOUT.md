# PayPal Business web checkout

SaveStream web uses PayPal Orders v2 for one-time credit packages. Mobile purchases remain on App Store / Google Play IAP.

## Security model

- `VITE_PAYPAL_CLIENT_ID` is public and may be embedded in the web bundle.
- The PayPal Client Secret is backend-only. Never put it in `VITE_*`, Git, CI logs, issue comments, or browser code.
- SaveStream creates the PayPal order on the backend from the server-side `CreditPackage` amount.
- The browser receives only the PayPal order ID and renders PayPal Smart Buttons.
- After buyer approval, the browser sends the PayPal order ID back to SaveStream.
- The backend verifies that the PayPal order ID belongs to the authenticated SaveStream `PaymentOrder`, captures it with PayPal REST API, verifies USD amount, then grants credits through the idempotent credit ledger.
- Repeated capture requests return the already-paid SaveStream order and never grant credits twice.

## How a payment is confirmed (no webhook needed)

This flow does not use PayPal webhooks, so nothing has to be set up in the PayPal dashboard for them:

- **Normal case:** the buyer approves in the PayPal popup and the browser calls SaveStream, which captures the order and grants credits.
- **Buyer closed the tab after approving:** the billing reconcile job (every 5 min) finds the PayPal order `APPROVED`, captures it and grants credits once. It keeps retrying for up to 3 × the pending expiry (default 24 h), then gives up.
- **Abandoned checkout** (never approved): the order expires after 24 h (`SAVESTREAM_PAYMENT_PENDING_EXPIRY_SECONDS`). PayPal never charged the buyer.
- **Refunds:** Admin → Payments → Refund calls PayPal's capture refund API. The reconcile job settles the refund status and the ledger exactly once.

## Turning on LIVE checkout (owner steps)

Status checked 2026-10-15 with the read-only *Production Diagnostics* workflow:

- the backend is `paypal`, LIVE (`https://api-m.paypal.com`), and the client ID and secret are set and accepted by PayPal (OAuth 200);
- the admin runtime flag `payment_web_enabled` is on; `/v1/public/pricing` reports `checkout.web = true`;
- **missing:** the web build has neither `VITE_BILLING_CHECKOUT_ENABLED` nor `VITE_PAYPAL_CLIENT_ID`, so `/billing` shows "Coming soon".

To turn it on:

1. In PayPal Developer → Apps & Credentials, select **Live** and copy the **Client ID** of the app SaveStream already uses (the same one the backend has). The Client ID is public; do **not** copy the secret anywhere.
2. In GitHub → repository Settings → Secrets and variables → Actions → **`WEB_ENV_PRODUCTION`** → Update, keep the existing lines and add:
   ```text
   VITE_BILLING_CHECKOUT_ENABLED=true
   VITE_PAYPAL_CLIENT_ID=<LIVE client ID from step 1>
   ```
3. Run **Deploy Web** (Actions → Deploy Web → Run workflow, `main`). The workflow stops if checkout is on but the client ID is missing, and prints `Checkout: ON`.
4. Open `https://savestream.online/billing` while signed in. "Coming soon" is gone and each pack shows **Buy**. Opening a pack shows the PayPal buttons.
5. Optional: run the smoke test below. A real purchase is the owner's decision.

To turn it off again: set `VITE_BILLING_CHECKOUT_ENABLED=false` (or remove the line) and run Deploy Web; or switch off `payment_web_enabled` in Admin → Settings, which closes checkout without a deploy.

## Sandbox

Use the PayPal sandbox API base URL while testing:

```text
SAVESTREAM_PAYMENT_PROVIDER=paypal
SAVESTREAM_PAYMENT_PROVIDER_BASE_URL=https://api-m.sandbox.paypal.com
SAVESTREAM_PAYPAL_CLIENT_ID=<sandbox client id>
SAVESTREAM_PAYPAL_CLIENT_SECRET=<sandbox secret, backend only>
VITE_PAYPAL_CLIENT_ID=<sandbox client id>
VITE_BILLING_CHECKOUT_ENABLED=true
```

Do not use sandbox credentials in production.

## Production credentials

On the VPS, run from the repository root:

```sh
sh deploy/vps/init-production-secrets.sh
```

Choose `paypal`. The script asks for the LIVE Client ID and reads the LIVE Client Secret with hidden input. The secret is stored in the protected `payment_api_key` secret file and is mounted into the backend as `SAVESTREAM_PAYPAL_CLIENT_SECRET_FILE`.

The generated non-secret `deploy/vps/production.env` should contain:

```text
SAVESTREAM_PAYMENT_PROVIDER=paypal
SAVESTREAM_PAYMENT_PROVIDER_BASE_URL=https://api-m.paypal.com
SAVESTREAM_PAYPAL_CLIENT_ID=<live client id>
```

Build the production web with:

```text
VITE_APP_MODE=production
VITE_API_BASE_URL=https://api.savestream.online
VITE_BILLING_CHECKOUT_ENABLED=true
VITE_PAYPAL_CLIENT_ID=<same live client id>
```

## Required smoke test before enabling public checkout

1. Sign in with a non-admin production test user.
2. Open `/billing` and select Starter.
3. Confirm PayPal Smart Buttons render without exposing a client secret in page source/network requests.
4. Complete one real low-value LIVE payment.
5. Verify the PayPal popup closes successfully and the SaveStream `PaymentOrder` becomes `paid`.
6. Verify credits increase exactly once.
7. Refresh the page and retry the capture request; credits must not increase a second time.
8. Confirm amount/currency in PayPal matches the package stored by SaveStream.
9. Test cancel: closing/cancelling PayPal must leave the order pending and must not add credits.
10. Test an admin refund before relying on refunds operationally.

Keep `VITE_BILLING_CHECKOUT_ENABLED=false` until this smoke test passes.
