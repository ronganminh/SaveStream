# Watches / Channels contract v0.1

The frontend product term **Channel** maps to the backend resource **Watch + resolved creator metadata**. V1 does not create a separate `channels` table or `/channels` API.

## Watch status enum

`active | paused | paused_insufficient_credit | paused_error | disabled`

`paused_quota` is not a valid status. Insufficient credit uses `paused_insufficient_credit`.

`live_status` is `unknown | offline | live`.

## Endpoints

- `POST /v1/watches`
- `GET /v1/watches` — cursor pagination.
- `GET /v1/watches/{watch_id}`
- `PATCH /v1/watches/{watch_id}`
- `DELETE /v1/watches/{watch_id}`
- `POST /v1/watches/{watch_id}/resume`

The scheduler owns live polling, jitter/backoff, and deduplication. The client never runs a long-lived process per Watch. When credit is insufficient, the Watch becomes `paused_insufficient_credit`; resuming can return `402 INSUFFICIENT_CREDITS`.

## Phase 5 implementation notes

The scheduler claims due rows in PostgreSQL using row locks and a lease, then enqueues a short live-check job. Successful checks calculate a jittered `next_check_at`; failures use bounded exponential backoff and eventually pause as `paused_error`.

If a Watch is LIVE and `auto_record=true`, the scheduler invokes the same recording application command used by manual recording. A deterministic user/room idempotency key plus the recording room/session unique key prevents duplicate recorders for the same TikTok room/session.

No Watch-specific SSE endpoint is introduced in v0.1. Recording progress uses the existing persisted SSE endpoint with `Last-Event-ID` resume. Watch/Channel state uses the Watch GET endpoint as the polling contract.
