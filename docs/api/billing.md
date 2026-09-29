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
