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

Pricing formula decisions such as per-minute vs storage, rounding, minimum charge, expiration, refund policy, currency, and tax are intentionally not hardcoded in v0.1. The frontend displays backend estimates and the settled `actual_cost`.
