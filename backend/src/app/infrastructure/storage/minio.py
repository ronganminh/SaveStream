from __future__ import annotations

import asyncio

import requests


class MinioHealthClient:
    def __init__(self, endpoint: str, timeout_seconds: float = 2.0) -> None:
        self.endpoint = endpoint.rstrip("/")
        self.timeout_seconds = timeout_seconds

    def _ping_sync(self) -> bool:
        response = requests.get(
            f"{self.endpoint}/minio/health/live",
            timeout=self.timeout_seconds,
        )
        return response.status_code == 200

    async def ping(self) -> bool:
        return await asyncio.to_thread(self._ping_sync)
