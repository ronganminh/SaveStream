# Privacy, deletion and content operations

This document describes SaveStream implementation behavior. It is not a substitute for jurisdiction-specific legal advice.

## User export

SaveStream provides a private authenticated `GET /v1/me/export` extension, excluded from frozen public OpenAPI v0.1. It returns profile, Watch, recording metadata, artifact metadata, credit ledger/reservations, payment/refund metadata and the user's audit actions. Secrets, token hashes and storage credentials are not exported.

## Account deletion

`DELETE /v1/me` immediately disables the account and revokes sessions. The Phase 9 privacy worker later anonymizes personal identifiers after the configured grace period.

The worker:

- removes credentials, sessions, one-time tokens and API keys;
- anonymizes email/display name;
- disables/anonymizes Watches;
- soft-deletes recordings and schedules artifact cleanup;
- removes IP/user-agent fields from the user's audit actions;
- preserves the minimum financial/ledger/payment references needed for accounting integrity.

Operators must choose and document `SAVESTREAM_ACCOUNT_DELETION_GRACE_DAYS` for the deployment.

## Retention

`SAVESTREAM_RECORDING_RETENTION_DAYS=0` disables automatic recording retention. A positive value soft-deletes terminal recordings older than the configured period and schedules artifact deletion.

Financial ledger/payment records are not automatically purged by the recording retention worker.

Retention periods must be selected by product/legal/operations for the actual jurisdictions and contractual requirements.

## Content policy implementation checklist

Before production launch, publish user-facing terms that address:

- users may only record/store content they are authorized to access and retain;
- prohibited unlawful, abusive or rights-infringing use;
- copyright/takedown/contact process;
- repeat-abuse handling;
- privacy requests and account deletion/export;
- platform/API terms applicable to supported sources;
- age/children requirements where applicable.

The backend should not be presented as bypassing access controls or content protections. Support/takedown operations should use audit trails and supported deletion flows.

## Legal review checklist

Obtain qualified review for privacy notice/consent, data processor/subprocessor disclosures, cross-border storage, retention periods, tax/invoice requirements, refund terms, copyright/takedown procedures and local consumer-protection obligations.
