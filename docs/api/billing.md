# Billing contract v0.1

## Payment states

`created -> pending -> paid`

`created | pending -> failed | cancelled | expired`

`paid -> partially_refunded -> refunded`

## Endpoints

- `GET /v1/billing/packages`
- `POST /v1/billing/payment-orders` — requires `Idempotency-Key`.
- `GET /v1/billing/payment-orders`
- `GET /v1/billing/payment-orders/{payment_order_id}`
- `POST /v1/billing/payment-orders/{payment_order_id}/checkout` — requires `Idempotency-Key`.
- `POST /v1/webhooks/payments/{provider}` — provider-signature authenticated; no user JWT.

A successful browser redirect is never proof that payment succeeded. The client must read/poll the payment-order status. Credits are posted only after verified webhook/reconciliation confirms a valid payment.

Provider and currency are deployment/product decisions, so the contract exposes `provider` as an opaque string and `Money.currency` as an ISO-4217 code rather than hardcoding a provider or currency.

## Phase 7 implementation

Payment order values are snapshots of the selected active package. A later package edit/disable does not change the order.

Checkout only transitions `created -> pending` and stores the provider reference/URL. It never grants credit.

The bundled provider adapters verify HMAC-SHA256 over the exact webhook raw body before JSON parsing. `payment_events` enforces provider-event uniqueness and stores unprocessed out-of-order events for reconciliation retry.

A verified `payment.paid` event must match the order amount and currency exactly. It transitions the order to `paid` and posts one idempotent credit grant.

Refund/partial-refund operations are internal in v0.1. Refund requests specify both minor money amount and credits to reverse, avoiding an implicit rounding policy. Credit reversal and provider refund handling remain append-only and idempotent.
