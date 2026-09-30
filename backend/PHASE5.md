# Phase 5 - Watch + Realtime

Phase 5 adds scheduled creator monitoring on top of the Phase 4 recording command and completes the frozen realtime behavior without adding new public endpoints.

## Watch model

Frontend **Channel** remains backend **Watch + creator metadata**.

Public status values stay frozen:

```text
active
paused
paused_insufficient_credit
paused_error
disabled
```

Live status stays:

```text
unknown
offline
live
```

## Scheduler flow

```text
Celery beat
  -> savestream.watch.scheduler_tick
  -> SELECT due watches FOR UPDATE SKIP LOCKED
  -> write scheduler lease + lease expiry
  -> enqueue savestream.watch.check
  -> resolve TikTok source
  -> update live_status / timestamps
  -> calculate jittered next_check_at
  -> if LIVE + auto_record:
       call RecordingService.create_for_user()
```

There is no infinite process per Watch.

### Jitter and backoff

Successful offline/live checks use separate configurable intervals plus jitter. Failed checks use exponential backoff capped by a maximum. After the configured consecutive-error threshold the Watch becomes `paused_error` and must be resumed explicitly.

### Claim and concurrency control

- PostgreSQL owns scheduler state.
- Claims use `FOR UPDATE SKIP LOCKED`.
- A scheduler lease prevents another tick from concurrently claiming the same Watch.
- Scheduler batch size bounds work per tick.
- Per-user active recording concurrency is capped before Watch auto-record creates more work.
- The recording worker keeps its independent lease/heartbeat protection from Phase 4.

## Room/session dedupe

Watch auto-record resolves to a TikTok `room_id` and calls the same recording application command used by manual recording.

The Watch idempotency key is deterministic from:

```text
user_id + room_id
```

Recordings also persist a private `room_session_key` unique constraint. Manual username/URL recordings set it after source resolution, so a manual recording and a Watch resolving to the same TikTok room/session cannot open two recorders concurrently.

## Pause / resume

- `PATCH /v1/watches/{id}` can set `active | paused | disabled`.
- `POST /v1/watches/{id}/resume` resumes backend/user paused states.
- `paused_error` is set by the scheduler after repeated live-check failures.
- `paused_insufficient_credit` is reserved for Phase 6. Phase 5 has no credit ledger, so resume does not yet produce a real insufficient-credit decision.

## Realtime contract

No Watch-specific SSE endpoint is added because it is not part of OpenAPI v0.1.

Recording realtime remains:

```text
GET /v1/recordings/{recording_id}/events
Last-Event-ID: <event id>
```

Events are persisted in PostgreSQL, so reconnect can resume after API restart. Polling fallback remains:

```text
GET /v1/recordings/{recording_id}
```

Watch/Channel state is polled from:

```text
GET /v1/watches/{watch_id}
```

with `last_checked_at`, `next_check_at`, `last_live_at` and `live_status`.

## Public endpoints

```text
POST   /v1/watches
GET    /v1/watches
GET    /v1/watches/{watch_id}
PATCH  /v1/watches/{watch_id}
DELETE /v1/watches/{watch_id}
POST   /v1/watches/{watch_id}/resume
```

## Not in Phase 5

- pricing rules;
- credit reservations/settlement;
- payment provider;
- Watch notification preferences;
- a new Watch SSE/WebSocket contract.
