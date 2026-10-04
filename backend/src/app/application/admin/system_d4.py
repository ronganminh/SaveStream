from __future__ import annotations

import asyncio
import smtplib
import ssl
from datetime import datetime
from typing import Any

from app.settings import AppSettings


class AdminSystemStatusService:
    def __init__(
        self,
        settings: AppSettings,
        *,
        database: Any,
        redis: Any,
        storage: Any,
    ) -> None:
        self.settings = settings
        self.database = database
        self.redis = redis
        self.storage = storage

    async def _check(self, checker) -> dict[str, str | None]:
        try:
            healthy = await checker()
            return {
                "status": "ok" if healthy else "error",
                "detail": None if healthy else "dependency returned unhealthy",
            }
        except Exception as exc:
            return {"status": "error", "detail": type(exc).__name__}

    def _smtp_ping(self) -> bool:
        with smtplib.SMTP(
            self.settings.smtp_host,
            self.settings.smtp_port,
            timeout=self.settings.dependency_timeout_seconds,
        ) as smtp:
            smtp.ehlo()
            if self.settings.smtp_starttls:
                smtp.starttls(context=ssl.create_default_context())
                smtp.ehlo()
            if self.settings.smtp_username:
                if not self.settings.smtp_password:
                    return False
                smtp.login(
                    self.settings.smtp_username,
                    self.settings.smtp_password,
                )
            code, _ = smtp.noop()
            return 200 <= code < 400

    async def status(
        self,
        *,
        backend_version: str,
        started_at: datetime,
    ) -> dict[str, object]:
        database, redis, storage = await asyncio.gather(
            self._check(self.database.ping),
            self._check(self.redis.ping),
            self._check(self.storage.ping),
        )
        try:
            smtp_ok = await asyncio.to_thread(self._smtp_ping)
            smtp = {
                "status": "ok" if smtp_ok else "error",
                "detail": None if smtp_ok else "dependency returned unhealthy",
            }
        except Exception as exc:
            smtp = {"status": "error", "detail": type(exc).__name__}

        return {
            "backend_version": backend_version,
            "started_at": started_at,
            "components": {
                "api": {"status": "ok", "detail": None},
                "database": database,
                "redis": redis,
                "storage": storage,
                "smtp": smtp,
            },
        }
