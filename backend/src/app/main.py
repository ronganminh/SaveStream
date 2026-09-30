from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.errors import install_exception_handlers
from app.api.middleware import GlobalRateLimitMiddleware, RequestIdMiddleware, SecurityHeadersMiddleware
from app.api.routes.admin import router as admin_router
from app.api.routes.artifacts import router as artifacts_router
from app.api.routes.auth import router as auth_router
from app.api.routes.billing import router as billing_router
from app.api.routes.credits import router as credits_router
from app.api.routes.health import router as health_router
from app.api.routes.operations import router as operations_router
from app.api.routes.pricing import router as pricing_router
from app.api.routes.recordings import router as recordings_router
from app.api.routes.users import router as users_router
from app.api.routes.watches import router as watches_router
from app.api.routes.webhooks import router as webhooks_router
from app.infrastructure.db.session import Database
from app.infrastructure.metrics.registry import MetricsMiddleware, MetricsRegistry
from app.infrastructure.rate_limit import RedisRateLimiter
from app.infrastructure.redis import RedisClient
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings, get_app_settings


def create_app(settings: AppSettings | None = None) -> FastAPI:
    cfg = settings or get_app_settings()
    metrics_registry = MetricsRegistry()

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
        docs_url=None if cfg.environment == "production" else "/docs",
        redoc_url=None if cfg.environment == "production" else "/redoc",
        openapi_url=None if cfg.environment == "production" else "/openapi.json",
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
    app.add_middleware(SecurityHeadersMiddleware, settings=cfg)
    app.add_middleware(GlobalRateLimitMiddleware, settings=cfg)
    app.add_middleware(MetricsMiddleware, registry=metrics_registry)
    app.add_middleware(RequestIdMiddleware, header_name=cfg.request_id_header)
    app.state.metrics_registry = metrics_registry
    install_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(users_router)
    app.include_router(recordings_router)
    app.include_router(artifacts_router)
    app.include_router(watches_router)
    app.include_router(credits_router)
    app.include_router(pricing_router)
    app.include_router(billing_router)
    app.include_router(webhooks_router)
    app.include_router(admin_router)
    app.include_router(operations_router)
    return app


app = create_app()
