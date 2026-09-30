# Credits and pricing contract v0.1

Credits are integers. Clients MUST NOT use floating point for balances or calculate the final charge themselves.

The balance DTO always returns all three values:

```json
{"posted":100,"reserved":30,"available":70}
```

Backend invariant: `available = posted - active reservations`. The ledger is append-only; corrections are compensating entries.

## Endpoints

- `GET /v1/credits/balance`
- `GET /v1/credits/transactions`
- `GET /v1/credits/reservations`
- `GET /v1/pricing`

Pricing formula decisions such as per-minute vs storage, rounding, minimum charge, expiration, refund policy, currency, and tax remain backend policy and are not encoded into the public v0.1 DTO.

## Phase 6 implementation

Recording creation resolves an active pricing rule, stores an immutable pricing snapshot, locks the user's credit account, calculates the configured maximum cost and reserves that amount in the same transaction as the queued recording/outbox event.

Settlement happens only after the recording artifact has uploaded successfully. Actual usage is evaluated against the saved pricing snapshot. The charge ledger reference is unique per recording, so worker retry/recovery cannot charge the recording twice. Any unused reservation is released.

If recording fails before settlement, the reservation is released without reducing posted balance.

If available credit is insufficient, recording creation returns HTTP 402 with `INSUFFICIENT_CREDITS`. Watch auto-record transitions to `paused_insufficient_credit`.

No pricing rule is activated by migration because product pricing decisions are not yet frozen. Pricing activation and credit adjustments are internal/admin operations until a public admin contract is explicitly frozen.
