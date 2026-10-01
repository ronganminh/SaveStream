from __future__ import annotations

import time

from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import get_app_settings


def main() -> None:
    settings = get_app_settings()
    storage = MinioStorageClient(settings)
    deadline = time.monotonic() + 60.0
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            storage.ensure_bucket()
            print(f"MinIO bucket ready: {settings.minio_bucket}")
            return
        except Exception as exc:
            last_error = exc
            time.sleep(1)
    raise RuntimeError(f"MinIO bucket init timed out: {last_error}")


if __name__ == "__main__":
    main()
