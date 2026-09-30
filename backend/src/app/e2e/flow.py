from __future__ import annotations

import hashlib
import hmac
import json
import os
import quopri
import re
import time
import uuid
from urllib.parse import unquote

import httpx

VERIFY_RE = re.compile(r"verify-email\?token=([^\s<>]+)")


def env(name: str, default: str) -> str:
    return os.getenv(name, default).rstrip("/")


def wait_ready(client: httpx.Client, api: str, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    last = ""
    while time.monotonic() < deadline:
        try:
            response = client.get(f"{api}/health/ready")
            if response.status_code == 200:
                return
            last = f"{response.status_code} {response.text[:160]}"
        except httpx.HTTPError as exc:
            last = str(exc)
        time.sleep(1)
    raise RuntimeError(f"API not ready: {last}")


def verification_token(
    client: httpx.Client,
    mailhog: str,
    email: str,
    timeout: float,
) -> str:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        response = client.get(f"{mailhog}/api/v2/messages")
        response.raise_for_status()
        for item in response.json().get("items", []):
            raw_json = json.dumps(item)
            if email not in raw_json:
                continue
            raw_data = str(item.get("Raw", {}).get("Data", ""))
            content_body = str(item.get("Content", {}).get("Body", ""))
            candidates = [raw_data, content_body, raw_json]
            for candidate in candidates:
                decoded = quopri.decodestring(candidate).decode(
                    "utf-8",
                    errors="replace",
                )
                match = VERIFY_RE.search(decoded)
                if match:
                    return unquote(match.group(1))
        time.sleep(1)
    raise RuntimeError("verification email not delivered")


def wait_recording(
    client: httpx.Client,
    api: str,
    headers: dict[str, str],
    recording_id: str,
    timeout: float,
) -> dict:
    deadline = time.monotonic() + timeout
    last: dict = {}
    while time.monotonic() < deadline:
        response = client.get(
            f"{api}/v1/recordings/{recording_id}",
            headers=headers,
        )
        response.raise_for_status()
        last = response.json()
        if last["status"] in {"completed", "failed", "stopped"}:
            return last
        time.sleep(1)
    raise RuntimeError(f"recording timeout: {last}")


def main() -> None:
    api = env("SAVESTREAM_E2E_API_URL", "http://api:8000")
    mailhog = env("SAVESTREAM_E2E_MAILHOG_URL", "http://mail-debug:8025")
    payment_secret = os.getenv(
        "SAVESTREAM_PAYMENT_WEBHOOK_SECRET",
        "savestream-fake-payment-secret",
    )
    timeout = float(os.getenv("SAVESTREAM_E2E_TIMEOUT_SECONDS", "120"))

    email = f"phase10-{uuid.uuid4().hex[:10]}@example.test"
    password = "E2E-Password-123!"

    with httpx.Client(timeout=20.0) as client:
        wait_ready(client, api, timeout)

        response = client.post(
            f"{api}/v1/auth/register",
            json={
                "email": email,
                "password": password,
                "display_name": "Phase 10 E2E",
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
                "password": password,
                "client_type": "mobile",
            },
        )
        response.raise_for_status()
        headers = {
            "Authorization": f"Bearer {response.json()['access_token']}"
        }

        response = client.get(f"{api}/v1/billing/packages", headers=headers)
        response.raise_for_status()
        packages = response.json()["items"]
        if len(packages) != 1:
            raise RuntimeError(f"expected one E2E package, got {len(packages)}")

        response = client.post(
            f"{api}/v1/billing/payment-orders",
            headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
            json={"package_id": packages[0]["id"]},
        )
        response.raise_for_status()
        order = response.json()

        response = client.post(
            f"{api}/v1/billing/payment-orders/{order['id']}/checkout",
            headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
            json={"return_url": "https://example.test/payment-return"},
        )
        response.raise_for_status()
        pending = response.json()["payment_order"]
        if pending["status"] != "pending":
            raise RuntimeError("checkout did not move payment to pending")

        response = client.get(f"{api}/v1/credits/balance", headers=headers)
        response.raise_for_status()
        if response.json()["posted"] != 0:
            raise RuntimeError("checkout incorrectly granted credits before payment proof")

        event = {
            "id": f"e2e-{uuid.uuid4()}",
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
        response = client.post(
            f"{api}/v1/webhooks/payments/fake",
            content=raw,
            headers={
                "Content-Type": "application/json",
                "X-Payment-Signature": signature,
            },
        )
        response.raise_for_status()

        response = client.get(f"{api}/v1/credits/balance", headers=headers)
        response.raise_for_status()
        if response.json()["posted"] != 100:
            raise RuntimeError("verified payment did not grant 100 credits")

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
        recording_id = response.json()["id"]

        recording = wait_recording(
            client,
            api,
            headers,
            recording_id,
            timeout,
        )
        if recording["status"] != "completed":
            raise RuntimeError(f"recording did not complete: {recording}")
        if recording["actual_cost"] != 1:
            raise RuntimeError(f"unexpected actual cost: {recording['actual_cost']}")

        response = client.get(f"{api}/v1/credits/balance", headers=headers)
        response.raise_for_status()
        if response.json()["posted"] != 99:
            raise RuntimeError("recording settlement did not debit one credit")

        response = client.get(
            f"{api}/v1/recordings/{recording_id}/artifacts",
            headers=headers,
        )
        response.raise_for_status()
        artifacts = response.json()["items"]
        if len(artifacts) != 1:
            raise RuntimeError("recording did not produce exactly one artifact")

        response = client.post(
            f"{api}/v1/artifacts/{artifacts[0]['id']}/download-url",
            headers=headers,
        )
        response.raise_for_status()
        media = client.get(response.json()["url"])
        media.raise_for_status()
        if len(media.content) <= 100_000:
            raise RuntimeError("downloaded artifact is unexpectedly small")

        response = client.delete(
            f"{api}/v1/recordings/{recording_id}",
            headers=headers,
        )
        if response.status_code != 204:
            raise RuntimeError("recording delete failed")

        response = client.delete(f"{api}/v1/me", headers=headers)
        if response.status_code != 202:
            raise RuntimeError("account deletion request failed")

    print(
        json.dumps(
            {
                "status": "passed",
                "flow": [
                    "register",
                    "verify",
                    "login",
                    "purchase",
                    "record",
                    "settle",
                    "download",
                    "delete",
                ],
            }
        )
    )


if __name__ == "__main__":
    main()
