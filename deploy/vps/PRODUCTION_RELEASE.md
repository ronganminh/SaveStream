# SaveStream production release runbook

This is the Phase 14 release gate for the production web + backend deployment.

Canonical production endpoints:

- Web: `https://savestream.online`
- API: `https://api.savestream.online`
- Lemon Squeezy webhook: `https://api.savestream.online/v1/webhooks/payments/lemonsqueezy`

Do not put secret values in Git, issue comments, CI logs, or chat.

## 1. Hard blockers

A production release must not proceed until all of these are true:

- `main` CI is green.
- Lemon Squeezy **Live Mode** is approved and a live one-time product/variant exists,
  **or** the release runs with payments disabled (see "Launching before Lemon Squeezy Live").
- When payments are enabled: live API key, live Store ID, live Variant ID, and live webhook secret are installed.
- Brevo production SMTP credentials and sender are verified.
- Production R2/S3 bucket and credentials are installed.
- DNS for `savestream.online` and `api.savestream.online` resolves to the intended production edge.
- TLS certificates for the API hostname are valid.
- A database backup exists and the restore drill is current.
- Operations alert delivery and metrics scraping are configured.

### Launching before Lemon Squeezy Live

Set `SAVESTREAM_PAYMENT_PROVIDER=disabled` (the secrets script asks for it) to ship auth, watches and recording while Live Mode is pending:

- the API starts without Live payment credentials; the payment secret files hold a `payments-disabled` placeholder;
- credit packages and payment-order history stay readable;
- checkout, refunds and payment webhooks fail closed with `503`, so no credits can be granted;
- the web build keeps `VITE_BILLING_CHECKOUT_ENABLED=false`;
- the release validator and smoke need `--allow-disabled-payments` / `--payments-disabled`.

To enable payments later, re-run the secrets script, answer `lemonsqueezy`, enter the Live credentials (the placeholders are replaced, everything else is kept), restart the stack, then follow section 9.

OAuth is intentionally **disabled** for this release. The current backend does not implement Google or Apple OAuth callbacks, so production web must not expose those entrypoints.

## 2. Build the production web

Use `apps/web/.env.production.example` as the source of truth:

```sh
VITE_APP_MODE=production
VITE_API_BASE_URL=https://api.savestream.online
VITE_BILLING_CHECKOUT_ENABLED=false
```

Keep hosted checkout disabled until the live provider setup below has passed its payment smoke. After that, rebuild with:

```sh
VITE_BILLING_CHECKOUT_ENABLED=true
```

The production web build must pass the Phase 13 cleanup audit and must not use demo repositories.

## 3. Provision production backend secrets

From the repository root on the VPS:

```sh
sh deploy/vps/init-production-secrets.sh
```

The script writes secret files under the production secret directory (default `~/savestream-secrets/production`) with mode 600 and writes non-secret deployment values to `deploy/vps/production.env`. It never prints secret values.

It is safe to re-run: existing secret files are kept (PostgreSQL/Redis passwords, JWT secret and metrics token are never rotated), credentials are only asked for when missing, previous answers are offered as defaults, and an existing `production.env` is backed up first. Connection URLs are rebuilt from the kept passwords.

Review the generated non-secret file:

```sh
cat deploy/vps/production.env
```

Confirm:

- frontend origin is `https://savestream.online`;
- CORS contains only intended HTTPS web origins;
- trusted proxy CIDRs match the actual reverse-proxy network;
- R2 endpoint and bucket are production resources;
- `SAVESTREAM_PAYMENT_PROVIDER` is `disabled` or `lemonsqueezy` as intended;
- Lemon Squeezy Store/Variant IDs (when enabled) are **Live**, not Test Mode;
- operations alert email is correct.

## 3a. Product catalog

Credit packages and the recording rate are database data, not migrations. The current
product decision (October 2026) is one-time credit packages:

| Code | Name | Credits | Price (USD) | Recording time |
|---|---|---|---|---|
| `starter` | Starter | 3,000 | 9.99 | 50 hours |
| `standard` | Standard | 9,000 | 24.99 | 150 hours |
| `premium` | Premium | 24,000 | 59.99 | 400 hours |

Recording rate: 1 credit = 1 minute (`duration_units_v1`, 60 s per unit, minimum 1 credit).
Free trial: `SAVESTREAM_SIGNUP_CREDITS=10`, granted once on first email verification.
Credits never expire. A recording is capped to the minutes the balance covers.

After the stack is running, create them once (they are not idempotent; check
`GET /v1/public/pricing` first):

```sh
C="docker compose --env-file deploy/vps/production.env -f deploy/vps/docker-compose.production.yml"
$C exec -T api savestream-credit-admin pricing-create --version credits-v1 \
  --policy-type duration_units_v1 \
  --policy-json '{"unit_seconds":60,"credits_per_unit":1,"minimum_credits":1}' \
  --public-rules-json '[{"code":"recording_duration","description":"1 credit per minute of recording","unit_seconds":60,"credits_per_unit":1}]' \
  --activate
$C exec -T api savestream-billing-admin package-create --code starter --name Starter --credits 3000 --amount-minor 999 --currency USD
$C exec -T api savestream-billing-admin package-create --code standard --name Standard --credits 9000 --amount-minor 2499 --currency USD
$C exec -T api savestream-billing-admin package-create --code premium --name Premium --credits 24000 --amount-minor 5999 --currency USD
```

Lemon Squeezy needs a single Live one-time variant; each order's amount is sent as
`custom_price` from the selected package.

## 4. Validate configuration before starting services

```sh
docker compose \
  --env-file deploy/vps/production.env \
  -f deploy/vps/docker-compose.production.yml \
  config --quiet
```

Build the API image, then run the application-level release validator without starting dependencies:

```sh
docker compose \
  --env-file deploy/vps/production.env \
  -f deploy/vps/docker-compose.production.yml \
  build api

docker compose \
  --env-file deploy/vps/production.env \
  -f deploy/vps/docker-compose.production.yml \
  run --rm --no-deps api \
  python -m app.release.readiness \
    --api-origin https://api.savestream.online \
    --frontend-origin https://savestream.online \
    --payment-webhook-url https://api.savestream.online/v1/webhooks/payments/lemonsqueezy
```

With payments disabled, append `--allow-disabled-payments` to the validator command.

The validator checks production mode, JSON logging, frontend/CORS alignment, HTTPS/security headers, trusted proxy configuration, TLS-backed S3 storage, non-default storage credentials, TikTok recording backend, Lemon Squeezy production adapter, SMTP and operations alerts. It does not print secrets.

## 5. Configure Nginx/TLS

Install `deploy/vps/nginx-production.conf.example` as the API virtual host after issuing the certificate for `api.savestream.online`.

Before reload:

```sh
sudo nginx -t
```

Then reload Nginx using the host's normal service manager.

The API container binds only to loopback on port 18001 by default.

## 6. Start production services

```sh
docker compose \
  --env-file deploy/vps/production.env \
  -f deploy/vps/docker-compose.production.yml \
  up -d --build
```

Check:

```sh
docker compose \
  --env-file deploy/vps/production.env \
  -f deploy/vps/docker-compose.production.yml \
  ps
```

Do not continue if API, worker, scheduler, outbox dispatcher, PostgreSQL, or Redis is unhealthy/restarting.

## 7. Run public production smoke

From a trusted machine with the backend Python dependencies installed:

```sh
python backend/scripts/release_smoke.py \
  --api-origin https://api.savestream.online \
  --frontend-origin https://savestream.online
```

With payments disabled, add `--payments-disabled`; the webhook check then expects `503` instead of `400`.

This verifies:

- liveness and readiness;
- HSTS and core security headers;
- production API docs are disabled;
- exact credentialed CORS for the web origin;
- an untrusted origin is not allowed;
- refresh without a cookie is rejected;
- an invalid Lemon Squeezy webhook signature is rejected.

## 8. Auth cookie manual smoke

Use a throwaway verified production account.

In browser devtools, confirm web login sets the refresh cookie with:

- `Secure`
- `HttpOnly`
- `SameSite=Lax`
- `Path=/v1/auth`

Refresh the page and confirm the session restores without storing a refresh token in localStorage/sessionStorage.

## 9. Payment Live smoke

Lemon Squeezy webhook configuration:

- URL: `https://api.savestream.online/v1/webhooks/payments/lemonsqueezy`
- Events: `order_created`, `order_refunded`
- Secret: same production webhook secret mounted into the API

With checkout still disabled on the public web build, test the backend/provider path using a controlled operator flow or temporary restricted build.

Verify:

1. payment order starts as created/pending;
2. provider checkout URL is HTTPS;
3. return URL is accepted only for `https://savestream.online/billing/success`;
4. credits are granted only after a verified provider webhook/reconciliation;
5. a bad webhook signature grants no credits;
6. refund updates the ledger exactly once.

Only after this passes should `VITE_BILLING_CHECKOUT_ENABLED=true` be shipped.

## 10. Storage and recording smoke

Use an authorized test TikTok channel.

Verify:

- watch creation succeeds;
- worker starts/finishes a recording;
- exactly one artifact is stored in the production R2/S3 bucket;
- presigned download is HTTPS and expires;
- temporary recording files are cleaned;
- credit reservation settles correctly;
- notification history receives the lifecycle event.

## 11. Observability

Before opening traffic, verify:

- JSON logs are being collected;
- request IDs appear in API logs;
- `/metrics` is not publicly accessible;
- metrics scraper can authenticate with the production metrics token;
- operations alert email can receive a controlled alert;
- outbox/payment/recording failure thresholds are visible to operators.

## 12. Release and rollback

Record before release:

- Git commit SHA;
- container image digest;
- Alembic revision;
- backup identifier;
- Lemon Squeezy Live Store/Variant IDs (IDs only, never secrets);
- release operator and timestamp.

Follow `deploy/STAGING_CANARY_ROLLBACK.md` for canary and rollback principles.

For rollback, prefer the previous application image while keeping schema compatibility. Do not restore an old database over newer payment/credit data without reconciliation.
