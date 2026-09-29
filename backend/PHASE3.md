# Phase 3 - Identity

Phase 3 implements the frozen authentication and user-session contract on top of the Phase 2 modular-monolith infrastructure.

## Security model

- Passwords are hashed with Argon2id and never logged or stored in plaintext.
- Access tokens are short-lived HS256 JWTs with issuer/audience validation.
- Refresh tokens are opaque random secrets. Only SHA-256 hashes are stored.
- A refresh token is bound to one `auth_sessions` row. Rotation stores prior hashes so reuse revokes that session/token family.
- Protected requests validate both the JWT and the current database session, so logout/session revoke takes effect immediately.
- Web refresh credentials use `Secure + HttpOnly + SameSite=Lax` cookies.
- Mobile receives the refresh token in JSON for OS secure storage.
- Verification/reset tokens are signed one-time JWTs backed by consumable `one_time_tokens` rows.
- Raw verification/reset tokens are reconstructed by the email worker; the outbox persists only `token_id`.
- Login and auth-write endpoints use Redis-backed rate limiting with hashed identifiers.
- Unknown email and known email return the same register/resend/forgot response text.
- Cross-user session revoke is scoped by `user_id` and returns not-found.

## Implemented endpoints

```text
POST   /v1/auth/register
POST   /v1/auth/verify-email
POST   /v1/auth/resend-verification
POST   /v1/auth/login
POST   /v1/auth/refresh
POST   /v1/auth/logout
POST   /v1/auth/logout-all
POST   /v1/auth/forgot-password
POST   /v1/auth/reset-password

GET    /v1/me
PATCH  /v1/me
DELETE /v1/me

GET    /v1/me/sessions
DELETE /v1/me/sessions/{session_id}
```

## Local email

Docker Compose points SMTP to the `mail-debug` service. Verification and reset messages are delivered through the transactional outbox and Celery worker.

Mail UI:

```text
http://localhost:8025
```

## Roles and scopes

V1 stores `users.role`. The built-in roles are `user` and `admin`; scope checks are centralized through `require_scopes()`. Phase 3 does not add admin HTTP endpoints.

## Account deletion

`DELETE /v1/me` records `deletion_requested_at`, disables login immediately, revokes active sessions and emits `identity.account_deletion_requested` through the outbox. Physical deletion/export/retention remains a later lifecycle phase.
