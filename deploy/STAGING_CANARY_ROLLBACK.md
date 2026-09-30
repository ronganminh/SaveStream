# Staging canary and rollback

## Before canary

- CI green on both supported Python versions.
- Migration upgrade/downgrade smoke is green.
- Backup completed and restore drill recently passed.
- Production/staging secret and quota values are explicitly configured.
- Payment provider is non-fake.
- CORS and trusted proxy CIDRs are exact.
- Alert delivery and metrics scraping are healthy.

## Canary

1. Deploy the new image to a small staging/canary pool.
2. Run `python backend/scripts/canary_check.py --base-url https://canary.example`.
3. Run a controlled authenticated flow: register/login -> Watch -> recording -> settle.
4. Run a provider sandbox payment and verify credits are granted only after webhook/reconciliation.
5. Run `load_probe.py` with a bounded request count.
6. Observe errors, latency, outbox backlog, recording failures and payment events for the agreed soak window.
7. Expand traffic only when metrics remain within release thresholds chosen by operators.

## Rollback

1. Stop traffic expansion.
2. Route traffic back to the previous image.
3. Keep workers compatible with the current schema.
4. Do not downgrade a migration while newer workers are still writing.
5. If schema rollback is required, stop writers first and check migration compatibility.
6. Run canary checks on the old image.
7. Reconcile outbox, payments, credits and stale recordings.

Data rollback is a last resort. Prefer forward fixes for financial/ledger data; never restore an old database over newer successful payments without reconciliation.

Record the image digest, migration revision, backup ID, rollback decision and incident/request IDs.
