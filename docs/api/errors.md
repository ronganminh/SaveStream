# Errors, pagination and idempotency contract v0.1

## Error envelope

```json
{
  "error": {
    "code": "INSUFFICIENT_CREDITS",
    "message": "Available credit is insufficient",
    "request_id": "req_...",
    "retryable": false,
    "details": {"required": 60, "available": 25}
  }
}
```

Clients MUST branch on `error.code`, not `message`. Frozen codes:

`AUTH_INVALID_CREDENTIALS`, `AUTH_EMAIL_NOT_VERIFIED`, `AUTH_SESSION_REVOKED`, `FORBIDDEN`, `RESOURCE_NOT_FOUND`, `VALIDATION_ERROR`, `RATE_LIMITED`, `IDEMPOTENCY_KEY_REUSED`, `STREAM_OFFLINE`, `STREAM_UNAVAILABLE`, `RECORDING_ALREADY_ACTIVE`, `RECORDING_NOT_STOPPABLE`, `INSUFFICIENT_CREDITS`, `PAYMENT_PENDING`, `PAYMENT_FAILED`, `SERVICE_UNAVAILABLE`, `INTERNAL_ERROR`.

## Pagination

Every list endpoint that can grow uses:

```json
{"items":[],"pagination":{"next_cursor":"cur_...","has_more":true}}
```

Query parameters are `limit` (1..100, default 20) and optional opaque `cursor`. Clients MUST NOT parse cursors.

## Idempotency

`Idempotency-Key` is required for:

- `POST /v1/recordings`
- `POST /v1/billing/payment-orders`
- `POST /v1/billing/payment-orders/{id}/checkout`

The admin credit-adjustment endpoint will also require it when the admin contract is frozen. Same key + same body replays the stored result. Same key + different body returns HTTP `409` with `IDEMPOTENCY_KEY_REUSED`.

Resource IDs are opaque strings. Backend implementations may use UUID or ULID, but clients MUST NOT infer type, timestamp, ownership, or resource kind from the ID value.
