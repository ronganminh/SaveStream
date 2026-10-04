# SaveStream Operations Runbook

This runbook covers Phase 8 operational triage. Production-hardening procedures such as WAF/TLS/IAM/backup drills remain Phase 9.

## First checks

1. Check `/health/live` and `/health/ready`.
2. Scrape `/metrics` with `X-Metrics-Token`.
3. Check the private admin operations snapshot.
4. Correlate errors using `X-Request-ID`.
5. Check worker, scheduler, outbox-dispatcher and API logs.

Do not edit credit balances, payment statuses or recording rows directly in PostgreSQL during normal incident response.

## Outbox backlog alert

Metric:

```text
savestream_pending_outbox_events
```

Triage:

1. Verify Redis/Celery availability.
2. Verify `outbox-dispatcher` is running.
3. Inspect `outbox_events.last_error` and `attempts`.
4. Fix the downstream dependency before manually retrying work.
5. Do not mark outbox rows published unless the event was actually handed to the queue.

## Recording failures alert

Metric:

```text
savestream_failed_recordings_recent
```

Triage:

1. Inspect recording `error_code`, `error_message`, room/source and worker attempts.
2. Check TikTok reachability, proxy/network and FFmpeg.
3. Check MinIO when failures happen during upload.
4. Check credit reservation state.
5. If the failure is retryable, use the private admin retry endpoint with a new UUID `Idempotency-Key`.

Admin retry creates a new recording. Never reset a failed recording row to `queued` manually.

## Unprocessed payment events alert

Metric:

```text
savestream_unprocessed_payment_events
```

Triage:

1. Inspect `payment_events.processing_error`.
2. Verify provider reference, amount and currency against the payment order.
3. Verify checkout/order state was committed.
4. Run payment reconciliation.
5. Confirm the provider directly before any manual support action.

A browser return/redirect is never payment proof. Never grant credits based only on the success page.

## Pending payment order investigation

Metric:

```text
savestream_pending_payment_orders
```

Triage:

1. Check provider status through reconciliation.
2. Check webhook delivery/signature errors.
3. Check event uniqueness and out-of-order events.
4. Do not change `pending -> paid` manually.
5. Credit grants must come from verified provider processing.

## Credit mismatch

Run:

```bash
savestream-credit-admin reconcile --user-id <uuid>
```

If inconsistent:

1. Inspect the latest ledger entry and active reservations.
2. Identify the missing/duplicate business reference.
3. Correct with a compensating ledger entry through supported admin tooling.
4. Never rewrite or delete historical ledger entries.

## Watch paused_error alert

Metric:

```text
savestream_paused_error_watches
```

Triage:

1. Inspect `last_error` and failure count.
2. Verify TikTok source resolution/network.
3. Fix the dependency.
4. Resume the Watch through the supported API after the issue is resolved.

For `paused_insufficient_credit`, investigate credit balance/reservations instead.

## Metrics unavailable

1. Confirm the metrics token is configured and the scraper sends `X-Metrics-Token`.
2. Check API readiness and DB connectivity.
3. Confirm `SAVESTREAM_METRICS_TOKEN` is not the local default in production.
4. Do not expose `/metrics` publicly without the token/reverse-proxy controls.

## Alert delivery unavailable

Operations alerts always log. SMTP is additional when `SAVESTREAM_OPS_ALERT_EMAIL` is configured.

1. Check application logs first.
2. Verify SMTP host/port and recipient configuration.
3. If Redis is unavailable, cooldown dedupe may be bypassed and duplicate alerts can occur; alerts should still be delivered.

## Admin account safety

- Admin endpoints require the `admin` role.
- An admin cannot deactivate or demote the account backing its current session.
- Review `/v1/admin/audit` after support changes.
- Use unique UUID idempotency keys for retry/credit/refund operations.

## Escalation data to collect

- UTC timestamp;
- request ID;
- user ID;
- recording/payment/watch ID;
- error code;
- relevant metric values;
- worker attempt/lease state;
- provider event ID/reference when payment-related.

Do not collect or paste access tokens, refresh tokens, payment secrets, webhook secrets or storage credentials into tickets.


## V2 recording capacity before paid launch

Production cloud recordings run on the dedicated `recordings` Celery queue. The current
production compose default is **6 concurrent recording worker slots**. V2 allows each Pro
account up to **3 simultaneous cloud recordings**, so six worker slots can saturate with only
two fully active Pro accounts.

Capacity planning rule:

```text
required_recording_slots =
  ceil(expected_simultaneously_active_pro_accounts * 3 * headroom_factor)
```

Use a headroom factor of at least `1.25` for launch planning, then validate the chosen value
with a load probe on the actual VPS before changing production. Do not raise concurrency from
the runbook alone: every recording slot can consume stream bandwidth, temporary disk,
FFmpeg/process memory, outbound upload bandwidth, Redis/Celery capacity, and object-storage
throughput.

Before enabling paid sales:

1. Measure CPU, memory, temporary disk usage, disk I/O and network ingress/egress while running
   representative simultaneous recordings.
2. Check the `recordings` queue depth and task start delay. A growing queue means worker
   capacity is below demand even if API latency is healthy.
3. Increase `SAVESTREAM_RECORDING_CONCURRENCY` in the production deployment environment from
   the current default of 6 only to the highest value proven stable by the load test.
4. Restart only the dedicated recorder worker and verify its effective Celery concurrency.
5. Run `backend/scripts/release_smoke.py` and create several concurrent test recordings.
6. Watch active recordings, waiting-for-cloud-slot count, missed-no-cloud-slot count, recorder
   CPU/memory, temporary disk, upload failures and recording start latency for at least one
   representative peak window.

Per-user cloud-slot waiting is separate from system capacity. `waiting_for_cloud_slot` means
the user has exhausted their own 3-slot entitlement; a Celery task waiting in the
`recordings` queue means the whole deployment has exhausted recorder workers. Both need to be
monitored because increasing the per-user limit does not increase server capacity.

If recorder CPU, memory, disk or bandwidth approaches the host limit, scale recorder capacity
before increasing paid traffic. Never compensate by weakening the per-user credit or
entitlement checks.
