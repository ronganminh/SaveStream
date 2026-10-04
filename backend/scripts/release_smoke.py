from __future__ import annotations

import argparse
import json
import os
import sys

import httpx


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def _check_app_status(client: httpx.Client, api: str) -> str | None:
    response = client.get(api + "/v1/app/status")
    if response.status_code != 200:
        return f"/v1/app/status returned {response.status_code}"
    try:
        payload = response.json()
    except ValueError:
        return "/v1/app/status returned invalid JSON"
    if not isinstance(payload, dict):
        return "/v1/app/status returned a non-object payload"
    versions = payload.get("min_supported_version")
    maintenance = payload.get("maintenance")
    if not isinstance(versions, dict) or not {
        "android",
        "ios",
    }.issubset(versions):
        return "/v1/app/status is missing min_supported_version.android/ios"
    if not isinstance(maintenance, dict) or "active" not in maintenance:
        return "/v1/app/status is missing maintenance.active"
    return None


def _check_entitlement(
    client: httpx.Client,
    api: str,
    access_token: str | None,
) -> str | None:
    headers = {"Authorization": f"Bearer {access_token}"} if access_token else {}
    response = client.get(api + "/v1/me/entitlement", headers=headers)
    if not access_token:
        if response.status_code != 401:
            return (
                "/v1/me/entitlement without release-smoke credentials must return "
                f"401, got {response.status_code}"
            )
        return None
    if response.status_code != 200:
        return f"/v1/me/entitlement returned {response.status_code}"
    try:
        payload = response.json()
    except ValueError:
        return "/v1/me/entitlement returned invalid JSON"
    if not isinstance(payload, dict):
        return "/v1/me/entitlement returned a non-object payload"
    if payload.get("plan") not in {"free", "pro"}:
        return "/v1/me/entitlement returned an invalid plan"
    if not isinstance(payload.get("limits"), dict):
        return "/v1/me/entitlement is missing limits"
    if not isinstance(payload.get("local"), dict):
        return "/v1/me/entitlement is missing local entitlement"
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Smoke-check a deployed SaveStream production API."
    )
    parser.add_argument(
        "--api-origin",
        default="https://api.savestream.online",
    )
    parser.add_argument(
        "--frontend-origin",
        default="https://savestream.online",
    )
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument(
        "--payments-disabled",
        action="store_true",
        help="Expect the payment webhook to fail closed with 503 (no live provider yet).",
    )
    args = parser.parse_args()

    api = args.api_origin.rstrip("/")
    frontend = args.frontend_origin.rstrip("/")
    release_smoke_access_token = os.environ.get(
        "SAVESTREAM_RELEASE_SMOKE_ACCESS_TOKEN"
    )

    with httpx.Client(
        timeout=args.timeout,
        follow_redirects=False,
    ) as client:
        for path in ("/health/live", "/health/ready"):
            response = client.get(api + path)
            if response.status_code != 200:
                return fail(f"{path} returned {response.status_code}")

        app_status_error = _check_app_status(client, api)
        if app_status_error:
            return fail(app_status_error)
        entitlement_error = _check_entitlement(
            client,
            api,
            release_smoke_access_token,
        )
        if entitlement_error:
            return fail(entitlement_error)

        live = client.get(api + "/health/live")
        required_headers = {
            "x-content-type-options": "nosniff",
            "x-frame-options": "DENY",
            "referrer-policy": "no-referrer",
        }
        for header, expected in required_headers.items():
            if live.headers.get(header) != expected:
                return fail(f"{header} is not {expected!r}")
        hsts = live.headers.get("strict-transport-security", "")
        if "max-age=" not in hsts:
            return fail("Strict-Transport-Security is missing")

        for path in ("/docs", "/redoc", "/openapi.json"):
            response = client.get(api + path)
            if response.status_code != 404:
                return fail(
                    f"production documentation route {path} returned "
                    f"{response.status_code}, expected 404"
                )

        preflight = client.options(
            api + "/v1/me",
            headers={
                "Origin": frontend,
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization,content-type",
            },
        )
        if preflight.status_code != 200:
            return fail(f"CORS preflight returned {preflight.status_code}")
        if preflight.headers.get("access-control-allow-origin") != frontend:
            return fail("CORS did not echo the exact frontend origin")
        if preflight.headers.get("access-control-allow-credentials") != "true":
            return fail("CORS credentials are not enabled")

        denied = client.options(
            api + "/v1/me",
            headers={
                "Origin": "https://release-smoke.invalid",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )
        if denied.headers.get("access-control-allow-origin"):
            return fail("untrusted CORS origin received allow-origin")

        refresh = client.post(
            api + "/v1/auth/refresh",
            headers={"Origin": frontend},
            json={},
        )
        if refresh.status_code != 401:
            return fail(
                "refresh without a session cookie must return 401, got "
                f"{refresh.status_code}"
            )
        if refresh.headers.get("access-control-allow-origin") != frontend:
            return fail("auth error response is missing exact CORS origin")

        webhook = client.post(
            api + "/v1/webhooks/payments/lemonsqueezy",
            content=json.dumps({"data": {}}),
            headers={
                "Content-Type": "application/json",
                "X-Signature": "invalid-release-smoke-signature",
            },
        )
        if args.payments_disabled:
            if webhook.status_code != 503:
                return fail(
                    "payment webhook must fail closed with 503 while payments are "
                    f"disabled, got {webhook.status_code}"
                )
        elif webhook.status_code != 400:
            return fail(
                "invalid Lemon Squeezy signature must be rejected with 400, got "
                f"{webhook.status_code}"
            )

    print("production release smoke passed")
    print(f"api origin: {api}")
    print(f"frontend origin: {frontend}")
    entitlement_mode = (
        "authenticated entitlement"
        if release_smoke_access_token
        else "entitlement auth boundary"
    )
    print(
        "checked: health, app status, "
        f"{entitlement_mode}, headers, CORS, docs disabled, auth boundary, "
        "webhook signature"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
