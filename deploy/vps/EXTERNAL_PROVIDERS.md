# External providers on SaveStream staging

The base staging stack intentionally keeps MailHog and the fake payment provider
for deterministic regression E2E. Use the external-provider overlay when testing
Brevo and Lemon Squeezy.

## Provider setup

Brevo:

- SMTP host: `smtp-relay.brevo.com`
- SMTP port: `587`
- STARTTLS: enabled
- Sender: `SaveStream <no-reply@savestream.online>`
- Use the SMTP login and SMTP key from Brevo. Do not use a Brevo API key as the
  SMTP password.

Lemon Squeezy Test Mode:

- Create a one-time product/variant whose currency matches the SaveStream credit
  package currency (staging packages currently use USD).
- SaveStream creates API checkouts with a custom price and includes the local
  `payment_order_id` in checkout custom data.
- Webhook URL:
  `https://staging-api.savestream.online/v1/webhooks/payments/lemonsqueezy`
- Subscribe to `order_created` and `order_refunded`.
- Use a dedicated webhook signing secret.

## Store secrets on the VPS

From `~/SaveStream`:

```sh
sh deploy/vps/configure-external-providers.sh
```

The script prompts for:

- Brevo SMTP login
- Brevo SMTP key
- Lemon Squeezy Test API key
- Lemon Squeezy webhook signing secret
- Lemon Squeezy Test Store ID
- Lemon Squeezy Test Variant ID

Secret values are written with mode 600 under the existing staging secret
directory. Store and variant IDs are written to
`deploy/vps/staging.external.env`.

## Enable Brevo + Lemon Squeezy

```sh
docker compose \
  --env-file deploy/vps/staging.env \
  --env-file deploy/vps/staging.external.env \
  -f deploy/vps/docker-compose.staging.yml \
  -f deploy/vps/docker-compose.staging.external.yml \
  config --quiet

docker compose \
  --env-file deploy/vps/staging.env \
  --env-file deploy/vps/staging.external.env \
  -f deploy/vps/docker-compose.staging.yml \
  -f deploy/vps/docker-compose.staging.external.yml \
  up -d --build
```

## Roll back to deterministic staging providers

The database, Redis and R2 data are preserved. Recreate the application
services from the base staging file:

```sh
docker compose \
  --env-file deploy/vps/staging.env \
  -f deploy/vps/docker-compose.staging.yml \
  up -d --build --force-recreate
```

## Production

Use live-mode Lemon Squeezy credentials only in production. The production
configuration rejects the fake payment provider, requires an HTTPS payment API,
requires a non-default webhook secret, and requires authenticated STARTTLS SMTP.
