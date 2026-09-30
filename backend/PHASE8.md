# Phase 8 - Admin + operations

Phase 8 adds the private support/operations surface described by the backend handoff without changing the frozen public OpenAPI v0.1 contract.

## Private admin surface

All routes below require an authenticated `admin` role and are excluded from generated OpenAPI:

```text
GET   /v1/admin/users
GET   /v1/admin/users/{user_id}
PATCH /v1/admin/users/{user_id}

GET   /v1/admin/recordings
GET   /v1/admin/recordings/{recording_id}
POST  /v1/admin/recordings/{recording_id}/retry

GET   /v1/admin/payments
POST  /v1/admin/payments/{payment_order_id}/refunds

POST  /v1/admin/credits/adjustments
GET   /v1/admin/audit

GET   /v1/admin/operations/snapshot
```

### Recording retry

Admin retry never rewrites a failed recording. It creates a new recording command from the failed recording's source/options and returns the new recording ID. This preserves the original event/credit/audit history.

Retry uses `Idempotency-Key` and the normal recording command, so credit reservation, active-source dedupe and outbox behavior are unchanged.

### Credit adjustment

Credit adjustment uses the Phase 6 append-only ledger and requires `Idempotency-Key`. The admin route writes the adjustment and audit row in the same database transaction.

### Audit

Admin mutations write `audit_logs` with:

- actor user ID;
- action;
- resource type/ID;
- request ID;
- client IP;
- user agent;
- structured details.

The audit table already existed in the Phase 2 base schema, so Phase 8 needs no new Alembic migration.

## Notification abstraction

Operations alerts depend on the application-level `NotificationSender` protocol.

Current infrastructure senders:

- structured logging (always);
- SMTP email when `SAVESTREAM_OPS_ALERT_EMAIL` is configured.

This keeps future Slack/PagerDuty/push adapters out of operations/domain code.

## Metrics

`GET /metrics` is excluded from public OpenAPI and requires:

```text
X-Metrics-Token: <SAVESTREAM_METRICS_TOKEN>
```

It exports Prometheus text-format metrics for HTTP request totals/duration plus DB-backed gauges:

- active recordings;
- recent failed recordings;
- pending outbox events;
- unprocessed payment events;
- pending payment orders;
- Watches paused with `paused_error`.

Production refuses the local default metrics token.

## Alerts

Celery Beat runs `savestream.operations.alerts`.

Configured thresholds cover:

- outbox backlog;
- recent recording failures;
- unprocessed payment events;
- paused-error Watches.

Redis is used only for alert cooldown/deduplication; it is not the source of operational truth. If Redis cooldown storage is unavailable, the alert is still delivered rather than silently dropped.

## Public contract

Public `docs/openapi.yaml` remains unchanged. Phase 8 private admin and metrics routes deliberately do not appear in generated OpenAPI.

Production hardening work such as TLS/WAF, secret-manager integration, retention, backup drills and network policy remains Phase 9.
