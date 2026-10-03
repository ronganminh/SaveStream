from __future__ import annotations

import asyncio
from datetime import timedelta
from pathlib import Path
from urllib.parse import urlparse

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

    def list_keys(self, *, limit: int) -> list[str]:
        self.ensure_bucket()
        keys: list[str] = []
        for item in self.client.list_objects(
            self.settings.minio_bucket,
            recursive=True,
        ):
            keys.append(item.object_name)
            if len(keys) >= limit:
                break
        return keys

    def _ping_sync(self) -> bool:
        return self.client.bucket_exists(self.settings.minio_bucket)

    async def ping(self) -> bool:
        return await asyncio.to_thread(self._ping_sync)


MinioHealthClient = MinioStorageClient
