# SaveStream API contract v0.1

`docs/openapi.yaml` is the source of truth for Web/Mobile integration after Phase 0.5. The Markdown files explain cross-cutting behavior but MUST NOT contradict OpenAPI.

## Frozen decisions

- Base path: `/v1`.
- JSON payloads and UTC ISO-8601 timestamps.
- Opaque resource IDs.
- Cursor pagination.
- Machine-readable `error.code` and `request_id`.
- Bearer access token.
- Web refresh credential in Secure + HttpOnly + SameSite=Lax cookie; mobile refresh token in secure OS storage.
- Recording status, Watch status, payment status, source types, and action booleans are frozen in OpenAPI.
- Frontend **Channel** = backend **Watch + creator metadata**.
- SSE uses `Last-Event-ID`; polling is the fallback.
- Client never decides final pricing, payment success, storage keys, or arbitrary output paths.

## Mock API

A local mock can be started directly from the frozen contract without adding a repository dependency:

```bash
npx -y @stoplight/prism-cli@5 mock docs/openapi.yaml --host 0.0.0.0 --port 4010
```

Generated clients should be generated from `docs/openapi.yaml`; do not hand-maintain duplicate DTOs in frontend code.
