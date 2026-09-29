# Recordings contract v0.1

## Source model

All live checks and recording commands use the same source DTO:

```json
{"source":{"type":"username","value":"creator_name"}}
```

`source.type` is frozen to `username | room_id | url`.

## Recording status enum

`queued | resolving | waiting_live | recording | processing | uploading | completed | failed | stop_requested | stopped`

State transitions are enforced by the backend domain/application layer. Route handlers and clients do not invent transitions.

## Actions

Every Recording DTO includes `actions.can_stop`, `actions.can_retry`, and `actions.can_delete`. Web/Mobile MUST use these booleans rather than reimplementing the state machine.

## Endpoints

- `POST /v1/live-status`
- `POST /v1/recordings` — requires `Idempotency-Key`, returns `202`.
- `GET /v1/recordings` — cursor pagination.
- `GET /v1/recordings/{recording_id}`
- `POST /v1/recordings/{recording_id}/stop` — asynchronous stop request, returns `202`.
- `GET /v1/recordings/{recording_id}/events` — SSE.
- `GET /v1/recordings/{recording_id}/artifacts`
- `DELETE /v1/recordings/{recording_id}` — soft-delete first.
- `POST /v1/artifacts/{artifact_id}/download-url` — returns an expiring authorized URL.

## SSE

Web uses `fetch()` streaming SSE so the Bearer header can be supplied. Clients reconnect with `Last-Event-ID`; polling `GET /v1/recordings/{id}` is the fallback. Each SSE `data` value is a `RecordingEvent` JSON object with `id`, monotonic `sequence`, `type`, `recording_id`, `created_at`, and `data`.

Presigned artifact URLs are ephemeral and MUST NOT be cached beyond `expires_at`.
