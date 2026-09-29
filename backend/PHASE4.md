# Phase 4 - Recording API

Phase 4 connects the reusable recording engine to the authenticated API and durable worker infrastructure.

## Public flow

```text
POST /v1/recordings + Idempotency-Key
  -> 202 queued
  -> transactional outbox
  -> Celery worker claims DB lease
  -> resolve/live check
  -> record with cooperative cancellation + heartbeat
  -> atomic FFmpeg remux
  -> checksum
  -> private MinIO upload
  -> completed/stopped
```

Clients can poll `GET /v1/recordings/{id}` or stream
`GET /v1/recordings/{id}/events` with `Last-Event-ID`.

## Durability and duplicate protection

- PostgreSQL is the source of truth for recording state.
- `active_dedupe_key` prevents two active recordings for the same owner/source.
- Workers claim a `worker_lease_id` and heartbeat.
- Duplicate Celery delivery is ignored while the existing lease is fresh.
- Celery beat scans stale leases and re-enqueues them for recovery.
- Stop requests are persisted as `stop_requested`; Redis is only a low-latency cancellation signal.
- Idempotent create replays the original recording for the same key/body and returns `IDEMPOTENCY_KEY_REUSED` for a different body.

## Storage

Artifacts live in a private S3-compatible bucket. The DB stores only the storage key, size and SHA-256 checksum. Download URLs are short-lived presigned URLs and are issued only after tenant authorization.

Soft-delete hides the recording immediately and sends `recording.cleanup` through the outbox. Cleanup removes private objects and local temp data.

## Temporary Phase 4 quota

Credit settlement is intentionally not implemented yet. Phase 4 reports zero estimated/actual credit cost and enforces a configurable hard maximum recording duration. The credit ledger arrives in the later pricing/credits phase.
