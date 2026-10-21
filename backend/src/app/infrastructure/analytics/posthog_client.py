"""Delivers queued analytics events (outbox topic analytics.capture) to PostHog."""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any

from app.settings import AppSettings, get_app_settings

logger = logging.getLogger("savestream.analytics")


@lru_cache(maxsize=4)
def _client(api_key: str, host: str):
    from posthog import Posthog

    # sync_mode: the outbox task is already off the request path, so send now
    # instead of starting a background thread inside the Celery worker.
    return Posthog(
        api_key,
        host=host,
        sync_mode=True,
        timeout=5,
        max_retries=1,
        disable_geoip=True,
    )


def deliver_analytics_event(payload: dict[str, Any], settings: AppSettings | None = None) -> bool:
    """Send one event; never raises, so a PostHog outage is only logged."""
    cfg = settings or get_app_settings()
    if not cfg.posthog_api_key:
        return False
    try:
        _client(cfg.posthog_api_key, cfg.posthog_host).capture(
            str(payload["event"]),
            distinct_id=str(payload["distinct_id"]),
            properties=dict(payload.get("properties") or {}),
            uuid=payload.get("uuid"),
        )
    except Exception as exc:  # noqa: BLE001 - analytics must never break the worker
        logger.warning(
            "posthog capture failed event=%s error=%s",
            payload.get("event"),
            type(exc).__name__,
        )
        return False
    return True
