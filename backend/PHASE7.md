# Phase 7 - Payment

Phase 7 adds credit packages, payment orders, checkout, verified provider events, refunds and payment reconciliation on top of the Phase 6 append-only credit ledger.

## Non-negotiable payment rule

A browser redirect or a successfully-created checkout is **never** proof of payment.

Credits are posted only when one of these trusted paths confirms payment:

1. a provider webhook whose signature is verified against the raw request body;
2. authenticated provider reconciliation.

Both paths use the same idempotent payment-event processor.

## Public contract

```text
GET  /v1/billing/packages

POST /v1/billing/payment-orders
GET  /v1/billing/payment-orders
GET  /v1/billing/payment-orders/{payment_order_id}

POST /v1/billing/payment-orders/{payment_order_id}/checkout

POST /v1/webhooks/payments/{provider}
```

Payment-order create and checkout require `Idempotency-Key`.

The webhook has no user Bearer authentication. It is authenticated by the configured payment adapter using the raw body and provider signature.

## State machine

```text
created -> pending -> paid
created | pending -> failed | cancelled | expired
paid -> partially_refunded -> refunded
```

## Provider architecture

Local/test defaults to the `fake` adapter.

Production cannot boot with `fake`. It requires:

- provider name;
- provider gateway base URL;
- API key;
- webhook secret.

`ConfiguredHttpPaymentProvider` speaks a small normalized gateway protocol so the application/domain layer stays provider-independent. A named provider-specific adapter can replace it without changing the public SaveStream API.

Webhook signature for the bundled adapters is HMAC-SHA256 over the exact raw body in `X-Payment-Signature`.

## Credit posting

A verified paid event writes one ledger grant with:

```text
reference_key = payment:{payment_order_id}:grant
```

The payment order is row-locked while processing, and the ledger reference is unique, so webhook + reconciliation races cannot double-grant credits.

## Out-of-order and duplicate events

`payment_events` enforces unique `(provider, provider_event_id)`.

If an event arrives before checkout state/reference is committed, it remains unprocessed with a diagnostic error. Reconciliation retries unprocessed events before querying provider state.

## Refunds

Refund policy is internal because v0.1 exposes no public refund endpoint.

The internal refund request explicitly supplies both:

- money in minor currency units;
- credits to reverse.

The backend does not invent a money-to-credit rounding rule.

Before calling the provider, refund credits are held through an append-only negative `refund` ledger entry. If the provider refund request or confirmed refund fails, a positive compensating `grant` restores those credits.

Successful refund events update the payment order to `partially_refunded` or `refunded`.

## Internal admin CLI

```bash
savestream-billing-admin package-create \
  --code starter \
  --name "Starter" \
  --credits 100 \
  --amount-minor 1000 \
  --currency USD

savestream-billing-admin package-disable --package-id <uuid>

savestream-billing-admin refund \
  --payment-order-id <uuid> \
  --amount-minor 500 \
  --credits 50 \
  --idempotency-key <uuid>

savestream-billing-admin reconcile
```

Packages are not seeded by migration because package price/currency are product decisions.

## Reconciliation

Celery Beat runs payment reconciliation periodically. It:

1. retries stored unprocessed events;
2. queries pending payments from the configured provider;
3. queries pending refunds;
4. feeds provider-confirmed state back through the same event processor.

Reconciliation never trusts frontend redirect state.
