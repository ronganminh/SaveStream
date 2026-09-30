# Phase 10 - Staging E2E + release validation

The original backend handoff stops the numbered implementation roadmap at Phase 9. Phase 10 is therefore a repository continuation derived from the handoff's explicit E2E staging and testing strategy rather than a new product/API phase.

## Source scope

The handoff's staging flow is:

```text
register
-> verify
-> login
-> purchase
-> record
-> settle
-> download
-> delete
```

Integration dependencies are real where the handoff asks for real containers:

- PostgreSQL
- Redis
- MinIO
- FFmpeg

Controlled fakes are used for:

- live stream source
- payment provider
- email provider

No public API contract is changed.

## Recording E2E runtime

Production continues to use the TikTok runtime.

Phase 10 adds an explicitly configured non-production recording backend:

```text
SAVESTREAM_RECORDING_SOURCE_BACKEND=fake_http
SAVESTREAM_E2E_STREAM_BASE_URL=http://fake-stream:8090
```

The worker still executes the real:

```text
RecordingEngine
-> stream bytes
-> temporary file
-> FFmpeg finalization
-> MinIO upload
-> credit settlement
-> completed recording
```

Only the source resolver/live gateway is replaced.

`fake_http` is rejected in production.

## Full-stack E2E stack

`backend/docker-compose.e2e.yml` extends the normal local stack with:

- `fake-stream`
- `e2e-runner`

The runner waits for API readiness, seeds one internal pricing rule and one credit package, then exercises only public application APIs for the user journey.

## E2E assertions

The flow verifies:

1. account registration;
2. verification email delivery through MailHog;
3. email verification token consumption;
4. mobile login;
5. billing package discovery;
6. idempotent payment-order creation and checkout;
7. checkout does **not** grant credits;
8. signed fake-provider webhook grants credits;
9. recording create queues a worker job;
10. worker records controlled live bytes;
11. FFmpeg produces a valid MP4 artifact;
12. MinIO stores the artifact;
13. credit settlement charges the saved pricing snapshot;
14. presigned download returns real media bytes;
15. recording deletion succeeds;
16. account deletion request succeeds.

## CI

Normal Backend CI validates both the standard Compose file and the E2E Compose overlay.

`.github/workflows/backend-e2e.yml` runs the full containerized flow on relevant pull requests and through `workflow_dispatch`.

On failure it prints API, worker, outbox, stream, email, MinIO, PostgreSQL and Redis logs before teardown.

## Scope boundary

This phase does not:

- add a new public endpoint;
- change the frozen OpenAPI v0.1 contract;
- use the real TikTok network in automated CI;
- use a real payment provider in automated CI;
- claim a production canary has run against live cloud infrastructure.

Production/sandbox canary with the selected real payment provider remains an environment-specific release activity.
