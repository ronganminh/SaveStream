from __future__ import annotations

import hashlib
import hmac
import json
from typing import Mapping

from app.domain.common.errors import ApplicationError

from .base import ProviderEvent


def verify_hmac_sha256(
    raw_body: bytes,
    headers: Mapping[str, str],
    secret: str,
) -> None:
    signature = ""
    for key, value in headers.items():
        if key.lower() == "x-payment-signature":
            signature = value.strip()
            break
    if signature.startswith("sha256="):
        signature = signature[7:]
    expected = hmac.new(
        secret.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    if not signature or not hmac.compare_digest(signature, expected):
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid payment webhook signature",
            status_code=400,
        )


def parse_standard_event(raw_body: bytes) -> ProviderEvent:
    try:
        payload = json.loads(raw_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid payment webhook payload",
            status_code=400,
        ) from exc
    if not isinstance(payload, dict):
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid payment webhook payload",
            status_code=400,
        )
    try:
        event_id = str(payload["id"])
        event_type = str(payload["type"])
        provider_reference = str(payload["payment_reference"])
    except KeyError as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Payment webhook is missing required fields",
            status_code=400,
        ) from exc
    if not event_id or not event_type or not provider_reference:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Payment webhook contains empty identifiers",
            status_code=400,
        )
    amount_minor_raw = payload.get("amount_minor")
    currency_raw = payload.get("currency")
    refund_reference_raw = payload.get("refund_reference")
    return ProviderEvent(
        event_id=event_id,
        event_type=event_type,
        provider_reference=provider_reference,
        amount_minor=(
            int(amount_minor_raw)
            if amount_minor_raw is not None
            else None
        ),
        currency=(
            str(currency_raw).upper()
            if currency_raw is not None
            else None
        ),
        refund_reference=(
            str(refund_reference_raw)
            if refund_reference_raw is not None
            else None
        ),
    )
