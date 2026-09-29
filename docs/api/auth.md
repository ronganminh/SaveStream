# Auth contract v0.1

This document freezes the Web/Mobile authentication transport for `/v1`.

## Tokens

- Access token: short-lived JWT, sent as `Authorization: Bearer <access-token>`.
- Web refresh credential: `Secure`, `HttpOnly`, `SameSite=Lax` cookie. It is never exposed to JavaScript and MUST NOT be stored in `localStorage`.
- Mobile refresh token: returned in login/refresh JSON and stored in Keychain / Android Keystore-backed secure storage.
- Every refresh rotates the refresh token. Reuse of an old token revokes the affected token family/session according to backend policy.

`POST /v1/auth/login` requires `client_type = web | mobile`. Web responses return `refresh_token: null` and set the cookie; mobile responses return the refresh token in JSON. `POST /v1/auth/refresh` uses the web cookie when the body token is absent, or the body token for mobile.

## Endpoints

- `POST /v1/auth/register`
- `POST /v1/auth/verify-email`
- `POST /v1/auth/resend-verification`
- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `POST /v1/auth/logout-all`
- `POST /v1/auth/forgot-password`
- `POST /v1/auth/reset-password`
- `GET /v1/me`
- `PATCH /v1/me`
- `GET /v1/me/sessions`
- `DELETE /v1/me/sessions/{session_id}`
- `DELETE /v1/me` starts the account-deletion workflow and returns `202`.

Clients branch on `error.code`, never on the human-readable `message`.
