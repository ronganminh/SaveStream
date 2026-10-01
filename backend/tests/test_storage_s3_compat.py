from __future__ import annotations

import asyncio

from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings


def _settings() -> AppSettings:
    return AppSettings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        redis_url="redis://localhost:6379/15",
        celery_broker_url="memory://",
        celery_result_backend="cache+memory://",
        minio_endpoint="https://example.r2.cloudflarestorage.com",
        minio_access_key="test-access",
        minio_secret_key="test-secret",
        minio_bucket="savestream-recordings",
        minio_secure=True,
    )


def test_storage_ping_uses_s3_bucket_check() -> None:
    storage = MinioStorageClient(_settings())

    class FakeClient:
        def __init__(self) -> None:
            self.requested_bucket: str | None = None

        def bucket_exists(self, bucket: str) -> bool:
            self.requested_bucket = bucket
            return True

    fake = FakeClient()
    storage.client = fake  # type: ignore[assignment]

    assert asyncio.run(storage.ping()) is True
    assert fake.requested_bucket == "savestream-recordings"


def test_storage_ping_returns_false_when_bucket_is_missing() -> None:
    storage = MinioStorageClient(_settings())

    class FakeClient:
        def bucket_exists(self, bucket: str) -> bool:
            del bucket
            return False

    storage.client = FakeClient()  # type: ignore[assignment]

    assert asyncio.run(storage.ping()) is False
