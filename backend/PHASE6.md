# Phase 6 - Pricing + Credit

Phase 6 replaces the temporary zero-cost recording model with a durable credit reservation and settlement system.

## Invariants

- Credits are integers. No floating-point balance or charge logic.
- `available = posted - active reservations`.
- The ledger is append-only. Corrections are compensating entries.
- A recording reserves its configured maximum cost before it is queued.
- Recording creation, reservation, idempotency row and outbox event commit together.
- Failed/stopped-before-start recordings release the unused reservation.
- Successful uploaded recordings settle actual usage and release the unused remainder.
- `credit_reservations.recording_id` is unique.
- Ledger `reference_key` is unique.
- Retrying settlement for the same recording can create at most one charge entry.
- Posted and available credit cannot become negative through application services.

## Pricing policy

Product pricing decisions are still intentionally not hardcoded. Migration `0005` does **not** activate a pricing rule.

A pricing rule is versioned data with:

- `policy_type`
- private evaluation `policy`
- public `rules` returned by `GET /v1/pricing`
- active/effective state

Each recording stores a pricing snapshot through its reservation. Later pricing changes do not change the cost formula for an already-reserved recording.

The backend currently has policy evaluators for `duration_units_v1` and `flat_v1`, but neither is selected automatically.

If no active rule exists, recording creation and `GET /v1/pricing` return `SERVICE_UNAVAILABLE`.

## Public endpoints

```text
GET /v1/credits/balance
GET /v1/credits/transactions
GET /v1/credits/reservations
GET /v1/pricing
```

The public OpenAPI v0.1 contract is unchanged.

## Internal admin CLI

Phase 6 intentionally does not expose an unfrozen public admin adjustment route.

Examples:

```bash
cd backend

savestream-credit-admin pricing-create \
  --version test-duration-v1 \
  --policy-type duration_units_v1 \
  --policy-json '{"unit_seconds":60,"credits_per_unit":2,"minimum_credits":0}' \
  --public-rules-json '[{"code":"recording_duration","description":"Configured duration pricing"}]' \
  --activate

savestream-credit-admin adjust \
  --user-id <uuid> \
  --amount 100 \
  --idempotency-key <uuid> \
  --reason "support adjustment"

savestream-credit-admin reconcile --user-id <uuid>
```

The example above demonstrates configuration only; it is not a production pricing recommendation.

## Watch integration

When a LIVE Watch with `auto_record=true` cannot reserve the configured maximum recording cost, it moves to:

```text
paused_insufficient_credit
```

`POST /v1/watches/{id}/resume` returns HTTP 402 `INSUFFICIENT_CREDITS` until the account can afford the configured maximum reservation.

## Reconciliation

Celery Beat runs `savestream.credits.reconcile` periodically. It compares:

- account posted balance;
- latest ledger balance;
- active reservations;
- calculated available balance.

It reports mismatches and does not rewrite historical ledger entries automatically.
