"""ASGI app of the downloader container: ``uvicorn app.downloader.app:app``.

Routes (behind nginx at /v1/public/video-downloader/):
- GET  status            whether the tool is on (the website hides it if not)
- POST resolve           check a TikTok link and return what may be downloaded
- GET  file/{token}      stream TikTok's downloadable file as an attachment
- GET  cover/{token}     stream the cover image (so the page never loads
                         TikTok's CDN directly)

Run with a single worker: the concurrent-stream cap is per process.
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse, Response, StreamingResponse
from pydantic import BaseModel, Field
from redis.asyncio import Redis

from app.api.errors import install_exception_handlers
from app.api.middleware import client_ip
from app.downloader.chain import ProviderChain
from app.downloader.config import DownloaderSettings, log_startup_state
from app.downloader.providers import TIMEOUTS, build_providers
from app.domain.common.errors import ApplicationError
from app.downloader.service import (
    COVER_MAX_BYTES,
    DownloaderService,
    TurnstileVerifier,
    stream_and_release,
    verify_turnstile,
)
from app.downloader.state import RedisLike

PREFIX = "/v1/public/video-downloader"
NO_STORE = {"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"}


class OwnerResolveRequest(BaseModel):
    url: str = Field(min_length=1, max_length=2048)
    grant: str = Field(min_length=1, max_length=4096)


class ResolveRequest(BaseModel):
    url: str = Field(min_length=1, max_length=2048)
    turnstile_token: str | None = Field(default=None, max_length=4096)


def build_service(
    settings: DownloaderSettings,
    *,
    redis: RedisLike,
    http: httpx.AsyncClient,
    chain: ProviderChain | None = None,
    turnstile: TurnstileVerifier | None = None,
) -> DownloaderService:
    proxy = settings.proxy_url or None
    return DownloaderService(
        settings=settings,
        redis=redis,
        chain=chain
        or ProviderChain(build_providers(settings.providers, proxy_url=proxy), dict(TIMEOUTS)),
        http=http,
        turnstile=turnstile
        or (lambda token, ip: verify_turnstile(settings.turnstile_secret_key, token, ip)),
        streams=asyncio.Semaphore(max(settings.max_streams, 1)),
    )


def create_app(
    settings: DownloaderSettings | None = None,
    *,
    service: DownloaderService | None = None,
) -> FastAPI:
    config = settings or (service.settings if service else DownloaderSettings.from_env())

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        log_startup_state(config)
        if service is not None:
            app.state.service = service
            yield
            return
        redis = Redis.from_url(config.redis_url, decode_responses=True)
        async with httpx.AsyncClient(
            proxy=config.proxy_url or None,
            timeout=httpx.Timeout(20.0, read=60.0),
            trust_env=False,
        ) as http:
            app.state.service = build_service(config, redis=redis, http=http)
            try:
                yield
            finally:
                await redis.aclose()

    app = FastAPI(
        title="SaveStream video downloader",
        lifespan=lifespan,
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    install_exception_handlers(app)
    if config.cors_allow_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(config.cors_allow_origins),
            allow_methods=["GET", "POST"],
            # The website's API client always sends X-Request-ID (and
            # Authorization when signed in; the downloader ignores it).
            allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
            expose_headers=["Retry-After", "Content-Disposition", "X-Request-ID"],
            allow_credentials=False,
            max_age=600,
        )
    if service is not None:
        app.state.service = service

    def svc(request: Request) -> DownloaderService:
        return request.app.state.service

    def ip_of(request: Request) -> str:
        return client_ip(request, config.trusted_proxy_cidrs)

    @app.get("/health/live")
    async def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get(f"{PREFIX}/status")
    async def status() -> JSONResponse:
        return JSONResponse(
            {
                "enabled": config.enabled,
                "turnstile_after": config.turnstile_after,
                "max_duration_seconds": config.max_duration_seconds,
                "max_bytes": config.max_bytes,
            },
            headers={"Cache-Control": "public, max-age=60"},
        )

    @app.post(f"{PREFIX}/resolve")
    async def resolve(payload: ResolveRequest, request: Request) -> JSONResponse:
        result = await svc(request).resolve(
            payload.url, ip=ip_of(request), turnstile_token=payload.turnstile_token
        )
        return JSONResponse(result, headers=NO_STORE)

    @app.get(f"{PREFIX}/file/{{token}}", response_model=None)
    async def file(token: str, request: Request) -> Response:
        service_ = svc(request)
        try:
            entry, media, release = await service_.open_file(
                token, ip=ip_of(request), kind="video"
            )
        except ApplicationError as exc:
            if exc.code != "LINK_EXPIRED":
                raise
            # A plain link click: send the visitor back to the page with a
            # message instead of showing them a JSON error.
            return RedirectResponse(
                f"{config.frontend_base_url}/video-downloader?expired=1", status_code=303
            )
        headers = {
            **NO_STORE,
            "Content-Disposition": f'attachment; filename="{entry.filename}"',
        }
        if media.size is not None:
            headers["Content-Length"] = str(media.size)
        return StreamingResponse(
            stream_and_release(media, config.max_bytes, release),
            media_type="video/mp4",
            headers=headers,
        )

    @app.post(f"{PREFIX}/owner/resolve")
    async def owner_resolve(payload: OwnerResolveRequest, request: Request) -> JSONResponse:
        result = await svc(request).owner_resolve(
            payload.url, grant_token=payload.grant, ip=ip_of(request)
        )
        return JSONResponse(result, headers=NO_STORE)

    @app.get(f"{PREFIX}/owner/file/{{token}}", response_model=None)
    async def owner_file(token: str, request: Request, grant: str = "") -> Response:
        try:
            entry, media, release = await svc(request).open_file(
                token, ip=ip_of(request), kind="video", grant_token=grant or None
            )
        except ApplicationError as exc:
            if exc.code not in {"LINK_EXPIRED", "GRANT_INVALID"}:
                raise
            return RedirectResponse(
                f"{config.frontend_base_url}/my-videos?expired=1", status_code=303
            )
        headers = {
            **NO_STORE,
            "Content-Disposition": f'attachment; filename="{entry.filename}"',
        }
        if media.size is not None:
            headers["Content-Length"] = str(media.size)
        return StreamingResponse(
            stream_and_release(media, config.max_bytes, release),
            media_type="video/mp4",
            headers=headers,
        )

    @app.get(f"{PREFIX}/cover/{{token}}")
    async def cover(token: str, request: Request) -> StreamingResponse:
        _, media, release = await svc(request).open_file(token, ip=ip_of(request), kind="cover")
        return StreamingResponse(
            stream_and_release(media, COVER_MAX_BYTES, release),
            media_type=media.content_type or "image/jpeg",
            headers={"Cache-Control": "private, max-age=600", "X-Content-Type-Options": "nosniff"},
        )

    return app


def __getattr__(name: str) -> FastAPI:
    # `uvicorn app.downloader.app:app` builds the app on first access, so
    # importing this module in tests does not read the environment.
    if name == "app":
        built = create_app()
        globals()["app"] = built
        return built
    raise AttributeError(name)
