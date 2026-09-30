from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.errors import install_exception_handlers
from app.api.middleware import RequestIdMiddleware
from app.api.routes.artifacts import router as artifacts_router
from app.api.routes.auth import router as auth_router
from app.api.routes.health import router as health_router
from app.api.routes.recordings import router as recordings_router
from app.api.routes.users import router as users_router
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import RedisRateLimiter
from app.infrastructure.redis import RedisClient
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings, get_app_settings


def create_app(settings: AppSettings | None = None) -> FastAPI:
    cfg = settings or get_app_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        database = Database(cfg.database_url)
        redis = RedisClient(cfg.redis_url)
        minio = MinioStorageClient(cfg)
        app.state.settings = cfg
        app.state.database = database
        app.state.redis = redis
        app.state.rate_limiter = RedisRateLimiter(redis.client)
        app.state.minio = minio
        try:
            yield
        finally:
            await redis.close()
            await database.close()

    app = FastAPI(
        title="SaveStream API",
        version="0.1.0",
        description="SaveStream modular-monolith API.",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(cfg.cors_allow_origins),
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=[
            "Authorization",
            "Content-Type",
            "Idempotency-Key",
            "Last-Event-ID",
            cfg.request_id_header,
        ],
        expose_headers=[cfg.request_id_header],
    )
    app.add_middleware(RequestIdMiddleware, header_name=cfg.request_id_header)
    install_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(users_router)
    app.include_router(recordings_router)
    app.include_router(artifacts_router)
    return app


app = create_app()
