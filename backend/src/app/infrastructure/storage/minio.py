from __future__ import annotations

import asyncio
from datetime import timedelta
from pathlib import Path
from urllib.parse import urlparse

import requests
from minio import Minio

from app.settings import AppSettings


class MinioStorageClient:
    def __init__(self, settings: AppSettings) -> None:
        self.settings = settings
        parsed = urlparse(settings.minio_endpoint)
        endpoint = parsed.netloc or parsed.path
        secure = settings.minio_secure or parsed.scheme == "https"
        self.client = Minio(
            endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=secure,
        )
        self.endpoint = settings.minio_endpoint.rstrip("/")

    def ensure_bucket(self) -> None:
        if not self.client.bucket_exists(self.settings.minio_bucket):
            self.client.make_bucket(self.settings.minio_bucket)

    def upload_file(
        self,
        source_path: Path,
        storage_key: str,
        *,
        content_type: str = "video/mp4",
    ) -> None:
        self.ensure_bucket()
        self.client.fput_object(
            self.settings.minio_bucket,
            storage_key,
            str(source_path),
            content_type=content_type,
        )

    def presigned_get_url(self, storage_key: str) -> str:
        return self.client.presigned_get_object(
            self.settings.minio_bucket,
            storage_key,
            expires=timedelta(seconds=self.settings.artifact_presign_seconds),
        )

    def remove(self, storage_key: str) -> None:
        self.client.remove_object(self.settings.minio_bucket, storage_key)

    def _ping_sync(self) -> bool:
        response = requests.get(
            f"{self.endpoint}/minio/health/live",
            timeout=self.settings.dependency_timeout_seconds,
        )
        return response.status_code == 200

    async def ping(self) -> bool:
        return await asyncio.to_thread(self._ping_sync)


MinioHealthClient = MinioStorageClient
