from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import Literal

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

router = APIRouter(tags=["Health"])


class ComponentHealth(BaseModel):
    status: Literal["ok", "error"]
    detail: str | None = None


class ReadinessResponse(BaseModel):
    status: Literal["ok", "error"]
    components: dict[str, ComponentHealth]


async def _check(
    name: str, checker: Callable[[], Awaitable[bool]]
) -> tuple[str, ComponentHealth]:
    try:
        healthy = await checker()
        if healthy:
            return name, ComponentHealth(status="ok")
        return name, ComponentHealth(status="error", detail="dependency returned unhealthy")
    except Exception as exc:
        return name, ComponentHealth(status="error", detail=type(exc).__name__)


@router.get("/health/live", include_in_schema=False)
async def live() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready", include_in_schema=False)
async def ready(request: Request) -> JSONResponse:
    checks = await asyncio.gather(
        _check("postgres", request.app.state.database.ping),
        _check("redis", request.app.state.redis.ping),
        _check("minio", request.app.state.minio.ping),
    )
    components = dict(checks)
    is_ready = all(item.status == "ok" for item in components.values())
    status: Literal["ok", "error"] = "ok" if is_ready else "error"
    payload = ReadinessResponse(
        status=status,
        components=components,
    )
    return JSONResponse(
        status_code=200 if is_ready else 503,
        content=payload.model_dump(),
    )
