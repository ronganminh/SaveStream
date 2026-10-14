from __future__ import annotations

import asyncio
import io
import os
from datetime import timedelta
from pathlib import Path
from urllib.parse import urlparse

import certifi
import urllib3
from minio import Minio
from minio.error import S3Error
from urllib3.util import Retry, Timeout

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
            # Same pool as Minio's default, with shorter socket timeouts (its
            # default is 5 minutes) so a stalled upload fails and is retried.
            http_client=urllib3.PoolManager(
                timeout=Timeout(
                    connect=settings.storage_connect_timeout_seconds,
                    read=settings.storage_read_timeout_seconds,
                ),
                maxsize=10,
                cert_reqs="CERT_REQUIRED",
                ca_certs=os.environ.get("SSL_CERT_FILE") or certifi.where(),
                retries=Retry(
                    total=5,
                    backoff_factor=0.2,
                    status_forcelist=[500, 502, 503, 504],
                ),
            ),
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

    def presigned_get_url(
        self,
        storage_key: str,
        *,
        content_disposition: str | None = None,
    ) -> str:
        """Signed GET URL. A `content_disposition` (e.g. attachment) is signed
        into the URL as `response-content-disposition`, so the browser saves
        the file instead of playing it."""
        response_headers: dict[str, str | list[str] | tuple[str]] | None = (
            {
                "response-content-disposition": content_disposition,
                "response-content-type": "video/mp4",
            }
            if content_disposition
            else None
        )
        return self.client.presigned_get_object(
            self.settings.minio_bucket,
            storage_key,
            expires=timedelta(seconds=self.settings.artifact_presign_seconds),
            response_headers=response_headers,
        )

    def upload_bytes(
        self,
        data: bytes,
        storage_key: str,
        *,
        content_type: str,
        cache_control: str | None = None,
    ) -> None:
        self.ensure_bucket()
        self.client.put_object(
            self.settings.minio_bucket,
            storage_key,
            io.BytesIO(data),
            length=len(data),
            content_type=content_type,
            metadata={"Cache-Control": cache_control} if cache_control else None,
        )

    def get_bytes(self, storage_key: str, *, max_bytes: int) -> tuple[bytes, str] | None:
        """Small object body and content type, or None when it does not exist."""
        try:
            response = self.client.get_object(self.settings.minio_bucket, storage_key)
        except S3Error as exc:
            if exc.code in {"NoSuchKey", "NoSuchBucket"}:
                return None
            raise
        try:
            data = response.read(max_bytes + 1)
            content_type = response.headers.get("Content-Type", "application/octet-stream")
        finally:
            response.close()
            response.release_conn()
        if len(data) > max_bytes:
            return None
        return data, content_type

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
