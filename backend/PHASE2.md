# Phase 2 - API skeleton, database and infrastructure

Phase 2 adds the modular-monolith runtime substrate without implementing identity or recording HTTP behavior.

## Included

- FastAPI application factory and health endpoints.
- Request ID middleware, CORS allowlist and frozen error envelope.
- Async SQLAlchemy database layer and Alembic.
- Base tables: `users`, `idempotency_keys`, `outbox_events`, `audit_logs`.
- Redis client for broker/cache infrastructure.
- Celery worker/beat bootstrap.
- Transactional outbox writer plus dispatcher base.
- MinIO local health integration. Upload/presign stays in the recording API phase.
- Local Docker Compose for API, worker, scheduler, outbox dispatcher, PostgreSQL, Redis, MinIO and mail debug.
- Contract tests that protect the frozen `docs/openapi.yaml` enums and operation IDs.

## Local start

```bash
cd backend
cp .env.example .env
docker compose up --build
```

Useful endpoints:

```text
GET http://localhost:8000/health/live
GET http://localhost:8000/health/ready
GET http://localhost:8000/docs
MinIO console: http://localhost:9001
Mail debug: http://localhost:8025
```

Health endpoints are operational endpoints and intentionally excluded from the frozen public OpenAPI contract.

## Migrations

```bash
cd backend
alembic upgrade head
alembic downgrade base
```

The production database remains PostgreSQL. SQLite is only used by fast CI migration/model smoke tests.

## Outbox rule

Application commands that need async work must write their domain state and `outbox_events` row in the same PostgreSQL transaction. The dispatcher publishes only committed rows to Celery. Future recording/watch/payment phases should build on this base instead of enqueueing before commit.

## Not in Phase 2

- password credentials, sessions or token rotation;
- recording HTTP endpoints or recording workers;
- Watch scheduling behavior;
- credit ledger/pricing;
- payment provider integration;
- artifact upload or presigned URL implementation.
