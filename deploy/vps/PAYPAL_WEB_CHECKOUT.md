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
