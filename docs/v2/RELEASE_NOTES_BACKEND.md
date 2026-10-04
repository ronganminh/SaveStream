# SaveStream V2 Backend Release Notes

This checklist covers the Track B V2 backend rollout. It intentionally does not modify
`deploy/vps/PRODUCTION_RELEASE.md`; production deployment files remain owner-managed.

## Database migrations

Apply Alembic migrations through `head` before enabling V2 clients. The V2 Track B migrations
currently include device/push, store-purchase and local-recording schema changes in the single
linear migration chain. Run both upgrade and downgrade checks in staging before production.

## New or changed environment settings

Review and explicitly configure these V2 settings before production rollout:

- `SAVESTREAM_STORE_PURCHASE_PROVIDER` and the Apple/Google store verification credentials.
  Keep the provider `disabled` until store configuration is complete.
- `SAVESTREAM_PRO_LOCAL_RECORDING`, `SAVESTREAM_FREE_LOCAL_DAILY_MINUTES`,
  `SAVESTREAM_REWARD_PROVIDER`, reward caps/timeouts and AdMob SSV verification settings.
- `SAVESTREAM_APP_MIN_SUPPORTED_ANDROID`, `SAVESTREAM_APP_MIN_SUPPORTED_IOS`,
  `SAVESTREAM_MAINTENANCE_ACTIVE` and optional maintenance ETA.
- `SAVESTREAM_RECORDING_RETENTION_DAYS_FREE`,
  `SAVESTREAM_RECORDING_EXPIRING_WINDOW_HOURS` and
  `SAVESTREAM_FREE_MINUTES_LOW_THRESHOLD`.
- Push-provider credentials and device notification settings introduced by B3.
- `SAVESTREAM_RECORDING_CONCURRENCY` on the dedicated production recorder worker. Production
  currently defaults to 6; determine a higher launch value from the capacity procedure in
  `backend/RUNBOOK.md` before paid sales.

Do not place secret values in this document or commit them to the repository.

## Recommended enablement order

1. Deploy schema and backend code with external integrations disabled.
2. Run the release smoke checks, including `GET /v1/app/status` and the authenticated
   `GET /v1/me/entitlement` check when a release-smoke token is available.
3. Validate recorder capacity and raise the production recorder concurrency from 6 to the
   load-tested value before opening paid sales.
4. Enable push after FCM credentials and token cleanup behavior are verified.
5. Enable rewarded-ad verification only after AdMob SSV is configured and callbacks are
   reaching the backend.
6. Enable App Store / Google Play purchase verification only after both provider credentials
   and webhook/server-notification delivery are verified.
7. Publish V2 web/mobile clients only after the matching backend feature gates are live.

## Manual owner actions

- Configure production secrets for Apple, Google, FCM and AdMob as applicable.
- Set the production minimum supported mobile versions and maintenance state.
- Load-test the actual recorder host, select the production
  `SAVESTREAM_RECORDING_CONCURRENCY`, and confirm the recorder worker starts with that value.
- Configure store products using the locked one-time package IDs and prices.
- Verify Apple/Google server notifications and AdMob SSV callback URLs in their provider
  consoles.
- Run the production release smoke. For the full entitlement shape check, provide a short-lived
  test access token in `SAVESTREAM_RELEASE_SMOKE_ACCESS_TOKEN`; without it the smoke still
  verifies that the endpoint is protected by authentication.
- Monitor the V2 metrics and recorder resource usage closely after enabling paid traffic.
