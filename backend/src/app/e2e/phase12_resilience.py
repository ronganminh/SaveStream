from __future__ import annotations

import hashlib
import hmac
import json
import os
import sys
import uuid
from typing import cast

import httpx
import redis

from app.e2e.flow import env, verification_token, wait_ready, wait_recording

API_RESTART_KEY = "savestream:e2e:phase12:api-restart"
WORKER_RESTART_KEY = "savestream:e2e:phase12:worker-restart"
PASSWORD = "Phase12-E2E-Password-123!"


def state_store() -> redis.Redis:
    return redis.Redis.from_url(
        os.getenv("SAVESTREAM_REDIS_URL", "redis://redis:6379/0"),
        decode_responses=True,
    )


def save_state(key: str, payload: dict[str, str]) -> None:
    state_store().set(key, json.dumps(payload), ex=1800)


def load_state(key: str) -> dict[str, str]:
    raw = cast(str | bytes | None, state_store().get(key))
    if raw is None:
        raise RuntimeError(f"missing Phase 12 E2E state: {key}")
    payload = json.loads(raw)
    if not isinstance(payload, dict):
        raise RuntimeError(f"invalid Phase 12 E2E state: {key}")
    return {str(k): str(v) for k, v in payload.items()}


def clear_state(key: str) -> None:
    state_store().delete(key)


def register_verified_user(
    client: httpx.Client,
    api: str,
    mailhog: str,
    timeout: float,
    label: str,
) -> tuple[str, str]:
    email = f"phase12-{label}-{uuid.uuid4().hex[:10]}@example.test"
    response = client.post(
        f"{api}/v1/auth/register",
        json={
            "email": email,
            "password": PASSWORD,
            "display_name": f"Phase 12 {label}",
        },
    )
    response.raise_for_status()

    token = verification_token(client, mailhog, email, timeout)
    response = client.post(
        f"{api}/v1/auth/verify-email",
        json={"token": token},
    )
    response.raise_for_status()

    response = client.post(
        f"{api}/v1/auth/login",
        json={
            "email": email,
            "password": PASSWORD,
            "client_type": "mobile",
        },
    )
    response.raise_for_status()
    return email, str(response.json()["access_token"])


def fund_credits(
    client: httpx.Client,
    api: str,
    headers: dict[str, str],
    payment_secret: str,
) -> None:
    packages_response = client.get(
        f"{api}/v1/billing/packages",
        headers=headers,
    )
    packages_response.raise_for_status()
    packages = packages_response.json()["items"]
    if len(packages) != 1:
        raise RuntimeError(f"expected one E2E package, got {len(packages)}")

    order_response = client.post(
        f"{api}/v1/billing/payment-orders",
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
        json={"package_id": packages[0]["id"]},
    )
    order_response.raise_for_status()
    order = order_response.json()

    checkout_response = client.post(
        f"{api}/v1/billing/payment-orders/{order['id']}/checkout",
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
        json={"return_url": "https://example.test/phase12-return"},
    )
    checkout_response.raise_for_status()
    pending = checkout_response.json()["payment_order"]

    event = {
        "id": f"phase12-{uuid.uuid4()}",
        "type": "payment.paid",
        "payment_reference": pending["provider_reference"],
        "amount_minor": order["amount"]["amount_minor"],
        "currency": order["amount"]["currency"],
    }
    raw = json.dumps(event, separators=(",", ":")).encode()
    signature = hmac.new(
        payment_secret.encode(),
        raw,
        hashlib.sha256,
    ).hexdigest()
    webhook = client.post(
        f"{api}/v1/webhooks/payments/fake",
        content=raw,
        headers={
            "Content-Type": "application/json",
            "X-Payment-Signature": signature,
        },
    )
    webhook.raise_for_status()

    balance = client.get(f"{api}/v1/credits/balance", headers=headers)
    balance.raise_for_status()
    if balance.json()["posted"] != 100:
        raise RuntimeError("Phase 12 funding did not grant 100 credits")


def prepare_api_restart() -> None:
    api = env("SAVESTREAM_E2E_API_URL", "http://api:8000")
    mailhog = env("SAVESTREAM_E2E_MAILHOG_URL", "http://mail-debug:8025")
    timeout = float(os.getenv("SAVESTREAM_E2E_TIMEOUT_SECONDS", "120"))
    with httpx.Client(timeout=20.0) as client:
        wait_ready(client, api, timeout)
        email, token = register_verified_user(
            client,
            api,
            mailhog,
            timeout,
            "api-restart",
        )
        headers = {"Authorization": f"Bearer {token}"}
        me = client.get(f"{api}/v1/me", headers=headers)
        me.raise_for_status()
        if me.json()["email"] != email:
            raise RuntimeError("pre-restart identity mismatch")
        save_state(API_RESTART_KEY, {"email": email, "access_token": token})


def verify_api_restart() -> None:
    api = env("SAVESTREAM_E2E_API_URL", "http://api:8000")
    timeout = float(os.getenv("SAVESTREAM_E2E_TIMEOUT_SECONDS", "120"))
    state = load_state(API_RESTART_KEY)
    with httpx.Client(timeout=20.0) as client:
        wait_ready(client, api, timeout)
        headers = {"Authorization": f"Bearer {state['access_token']}"}
        me = client.get(f"{api}/v1/me", headers=headers)
        me.raise_for_status()
        if me.json()["email"] != state["email"]:
            raise RuntimeError("session did not survive API restart")
        preferences = client.get(
            f"{api}/v1/me/notification-preferences",
            headers=headers,
        )
        preferences.raise_for_status()
    clear_state(API_RESTART_KEY)


def prepare_worker_restart() -> None:
    api = env("SAVESTREAM_E2E_API_URL", "http://api:8000")
    mailhog = env("SAVESTREAM_E2E_MAILHOG_URL", "http://mail-debug:8025")
    payment_secret = os.getenv(
        "SAVESTREAM_PAYMENT_WEBHOOK_SECRET",
        "savestream-fake-payment-secret",
    )
    timeout = float(os.getenv("SAVESTREAM_E2E_TIMEOUT_SECONDS", "120"))

    with httpx.Client(timeout=20.0) as client:
        wait_ready(client, api, timeout)
        email, token = register_verified_user(
            client,
            api,
            mailhog,
            timeout,
            "worker-restart",
        )
        headers = {"Authorization": f"Bearer {token}"}
        fund_credits(client, api, headers, payment_secret)

        response = client.post(
            f"{api}/v1/recordings",
            headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
            json={
                "source": {"type": "room_id", "value": "e2e-room"},
                "max_duration_seconds": 3,
                "quality": "best",
                "container": "mp4",
            },
        )
        response.raise_for_status()
        recording = response.json()
        if recording["status"] != "queued":
            raise RuntimeError(
                f"expected queued recording with worker stopped, got {recording['status']}"
            )
        save_state(
            WORKER_RESTART_KEY,
            {
                "email": email,
                "access_token": token,
                "recording_id": str(recording["id"]),
            },
        )


def verify_worker_restart() -> None:
    api = env("SAVESTREAM_E2E_API_URL", "http://api:8000")
    timeout = float(os.getenv("SAVESTREAM_E2E_TIMEOUT_SECONDS", "120"))
    state = load_state(WORKER_RESTART_KEY)
    headers = {"Authorization": f"Bearer {state['access_token']}"}

    with httpx.Client(timeout=20.0) as client:
        wait_ready(client, api, timeout)
        recording = wait_recording(
            client,
            api,
            headers,
            state["recording_id"],
            timeout,
        )
        if recording["status"] != "completed":
            raise RuntimeError(
                f"queued recording did not recover after worker restart: {recording}"
            )
        artifacts_response = client.get(
            f"{api}/v1/recordings/{state['recording_id']}/artifacts",
            headers=headers,
        )
        artifacts_response.raise_for_status()
        if len(artifacts_response.json()["items"]) != 1:
            raise RuntimeError("worker restart recovery did not produce one artifact")
        balance = client.get(f"{api}/v1/credits/balance", headers=headers)
        balance.raise_for_status()
        if balance.json()["posted"] != 99:
            raise RuntimeError("worker restart recovery did not settle credits")
    clear_state(WORKER_RESTART_KEY)


def main() -> None:
    commands = {
        "prepare-api-restart": prepare_api_restart,
        "verify-api-restart": verify_api_restart,
        "prepare-worker-restart": prepare_worker_restart,
        "verify-worker-restart": verify_worker_restart,
    }
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        raise SystemExit(
            "usage: python -m app.e2e.phase12_resilience "
            "<prepare-api-restart|verify-api-restart|"
            "prepare-worker-restart|verify-worker-restart>"
        )
    commands[sys.argv[1]]()
    print(json.dumps({"status": "passed", "phase12": sys.argv[1]}))


if __name__ == "__main__":
    main()
