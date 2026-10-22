# Recordings contract v0.1

## Source model

All live checks and recording commands use the same source DTO:

```json
{"source":{"type":"username","value":"creator_name"}}
```

`source.type` is frozen to `username | room_id | url`.

## Recording status enum

`queued | resolving | waiting_live | recording | processing | uploading | completed | failed | stop_requested | stopped | waiting_for_cloud_slot | missed_no_cloud_slot`

State transitions are enforced by the backend domain/application layer. Route handlers and clients do not invent transitions.

## Actions

Every Recording DTO includes `actions.can_stop`, `actions.can_retry`, and `actions.can_delete`. Web/Mobile MUST use these booleans rather than reimplementing the state machine.

## Failure reasons

`error` (`code`, `message`, `retryable`) is technical and unchanged. For users, every Recording DTO also carries `failure_reason` and `failure_guidance`: fixed plain-English strings that never contain raw error text, URLs or paths. Both are `null` unless `status` is `failed` or `missed_no_cloud_slot`; `failure_guidance` may also be `null`. Clients SHOULD show these instead of `error.message`.

| Code / state | `failure_reason` | `failure_guidance` |
|---|---|---|
| `STREAM_OFFLINE` | The LIVE ended before recording could start. | Very short LIVEs (under about a minute) may not be captured. |
| `STREAM_UNAVAILABLE` | We couldn't connect to this LIVE's video stream. | This is usually temporary. Try again while the creator is still LIVE. |
| `STREAM_UNAVAILABLE` (capture saved no video) | The LIVE ended before any video could be saved. | Very short LIVEs (under about a minute) may not be captured. |
| `SERVICE_UNAVAILABLE` | Our recording service ran into a problem with this recording. | This was a problem on our side. Contact support if this keeps happening. |
| `SERVICE_UNAVAILABLE` (upload failed) | The LIVE was recorded, but we couldn't save the video file. | This was a problem on our side. Contact support if this keeps happening. |
| `SERVICE_UNAVAILABLE` (retry limit) | Our recorder couldn't finish this recording after several tries. | This was a problem on our side. Contact support if this keeps happening. |
| `missed_no_cloud_slot` | All your cloud recording slots were busy, so this LIVE wasn't recorded. | This happens when other recordings are already using every cloud slot you have at the same time. |
| any other code | Something went wrong while saving this recording. | Please report a problem if this keeps happening. |

When nothing was charged (`minutes_charged` is 0, which is always the case for failed and missed recordings: the credit reservation is released), the guidance ends with "You weren't charged for this recording."

Example (failed upload):

```json
{
  "status": "failed",
  "error": {"code": "SERVICE_UNAVAILABLE", "message": "Artifact upload failed: …", "retryable": true},
  "failure_reason": "The LIVE was recorded, but we couldn't save the video file.",
  "failure_guidance": "This was a problem on our side. Contact support if this keeps happening. You weren't charged for this recording.",
  "minutes_charged": 0
}
```

## Endpoints

- `POST /v1/live-status` — `200` with `live_status: "offline"` and `room_id: null` for a real creator who is not LIVE (or never was); `404 CHANNEL_NOT_FOUND` when TikTok's profile page says the username does not exist (username and profile-URL sources only); `503 STREAM_UNAVAILABLE` when TikTok can't be read or doesn't say.
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
