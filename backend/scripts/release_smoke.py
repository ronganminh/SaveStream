from __future__ import annotations

import argparse
import json
import sys

import httpx


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


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

    with httpx.Client(
        timeout=args.timeout,
        follow_redirects=False,
    ) as client:
        for path in ("/health/live", "/health/ready"):
            response = client.get(api + path)
            if response.status_code != 200:
                return fail(f"{path} returned {response.status_code}")

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
    print("checked: health, headers, CORS, docs disabled, auth boundary, webhook signature")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
