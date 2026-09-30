# Phase 9 - Production hardening

Phase 9 implements the production-hardening scope from the backend handoff while keeping the frozen public OpenAPI v0.1 unchanged.

## Application hardening

- Global Redis-backed API rate limiting in addition to the existing auth-specific limits.
- Per-user limits for Watches, active recordings and recordings created per day.
- Trusted-proxy CIDR handling for forwarded client IP and protocol.
- HTTPS enforcement in production.
- Strict production CORS validation: no wildcard, localhost or non-HTTPS origins.
- Security headers: HSTS, CSP, frame denial, nosniff, referrer policy, permissions policy and no-store on sensitive routes.
- Interactive FastAPI docs and runtime OpenAPI endpoint disabled in production.
- Sensitive settings support mounted secret files through `SAVESTREAM_<NAME>_FILE`.
- JWT key rotation supports a current signing key plus temporary previous verification keys.

Global rate limiting fails closed with `SERVICE_UNAVAILABLE` if the limiter dependency is unavailable. Health, metrics and verified payment webhook paths retain their dedicated controls.

## Quotas

The following controls are environment-configurable:

```text
SAVESTREAM_QUOTA_MAX_WATCHES_PER_USER
SAVESTREAM_QUOTA_MAX_RECORDINGS_PER_DAY
SAVESTREAM_QUOTA_MAX_ACTIVE_RECORDINGS_PER_USER
```

A zero value disables a quota when constructing application settings directly for local/test scenarios. Production settings require positive values.

Quota checks return the frozen `RATE_LIMITED` error envelope and run after idempotency replay, so a legitimate replay is not rejected because the quota became full after the original request.

## Privacy, export and retention

Migration `0007_phase9_privacy` adds `users.deletion_completed_at` and an index for due deletion work.

- `DELETE /v1/me` still immediately disables the account and revokes sessions.
- A periodic privacy worker anonymizes due deletion requests after the configured grace period.
- Credentials, sessions, one-time tokens and API keys are removed.
- Watch and recording source identifiers are anonymized.
- Recording artifacts are scheduled through the existing cleanup outbox path.
- User audit IP/user-agent data is removed.
- Financial ledger/payment records are preserved against an anonymized user row so accounting history is not rewritten.
- `GET /v1/me/export` is an authenticated private extension excluded from frozen public OpenAPI v0.1.
- Configurable recording retention soft-deletes old terminal recordings and schedules artifact cleanup.
- Expired one-time-token and idempotency rows are pruned.

`SAVESTREAM_RECORDING_RETENTION_DAYS=0` disables automatic content retention. The production value must be chosen and documented by product/legal/operations rather than invented by backend code.

## Backup and restore

Repository tooling includes:

```text
backend/scripts/backup.sh
backend/scripts/restore.sh
backend/scripts/backup_restore_drill.sh
```

The backup covers PostgreSQL and the recording object bucket, creates a SHA256 manifest, and the restore path verifies it before restoration.

The restore command is intentionally guarded and requires explicit confirmation. A restore drill can validate archive integrity without modifying production and can optionally restore to a scratch database.

## Load, soak and failure checks

- `backend/scripts/load_probe.py` provides bounded concurrent load/soak probing.
- `backend/scripts/canary_check.py` validates liveness, readiness and key security headers.
- Tests cover loss of the rate-limit dependency and verify the API fails closed rather than silently bypassing the control.
- Existing worker lease/recovery, outbox retry, payment reconciliation and recording recovery tests remain part of the full CI suite.

These tools are bounded probes, not a claim that a production-scale load or chaos campaign has already been executed against real infrastructure.

## Deployment security baseline

Repository assets include:

- `deploy/nginx.conf`: TLS/reverse-proxy and edge rate-limit baseline.
- `deploy/k8s/security-baseline.yaml`: restricted namespace, ServiceAccount without API token automount, default-deny network policy and explicit service paths.
- `docker-compose.production.example.yml`: production topology example using mounted secret files.
- `deploy/SECURITY.md`: TLS/WAF/secrets/key-rotation/IAM/network guidance.
- `deploy/STAGING_CANARY_ROLLBACK.md`: staging, canary and rollback checklist.
- `docs/operations/PRIVACY_CONTENT.md`: privacy, retention, export/deletion, content-policy and legal-review checklist.

A real managed WAF, certificate issuer, cloud IAM/workload identity, cloud secret manager and environment-specific egress policy must still be enabled in the target deployment. Phase 9 does not claim external cloud controls are already active.

## CI gates

Backend CI validates on Python 3.11 and 3.12:

- Ruff;
- mypy;
- full pytest suite;
- Alembic upgrade through migration 0007 and downgrade to base;
- production settings smoke with hardened values;
- backup/restore shell syntax;
- canary/load Python syntax;
- installed dependency consistency;
- local Docker Compose configuration;
- legacy CLI smoke.

## Production launch checklist

Before real production traffic:

1. choose explicit quota and retention values;
2. configure exact HTTPS CORS origins and trusted proxy CIDRs;
3. enable managed TLS/WAF/edge rate limiting;
4. mount secrets from the selected secret manager;
5. configure least-privilege workload identities;
6. apply environment-specific ingress/egress network policy;
7. run and record a PostgreSQL + object-storage backup/restore drill;
8. complete privacy/content/legal review for the launch jurisdictions;
9. run staging canary plus bounded load/soak tests;
10. verify the previous image digest and rollback procedure;
11. verify payment reconciliation, credit reconciliation and alert delivery after deployment.
