from __future__ import annotations

import hmac
import ipaddress
import logging
import re
import uuid
from collections.abc import Sequence

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import AdminSecuritySignal
from app.settings import AppSettings

_REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
logger = logging.getLogger("savestream.api.security")


async def _record_rate_limit_signal(request: Request, identifier: str) -> None:
    database = getattr(request.app.state, "database", None)
    if database is None:
        return
    try:
        async with database.session() as session:
            session.add(
                AdminSecuritySignal(
                    event_type="rate_limited",
                    ip_address=identifier,
                    details={
                        "path": request.url.path[:500],
                        "method": request.method,
                    },
                )
            )
            await session.commit()
    except Exception:
        logger.exception("failed to persist rate-limit security signal")


def _networks(values: Sequence[str]) -> tuple[ipaddress._BaseNetwork, ...]:
    networks: list[ipaddress._BaseNetwork] = []
    for value in values:
        networks.append(ipaddress.ip_network(value, strict=False))
    return tuple(networks)


def client_ip(request: Request, trusted_proxy_cidrs: Sequence[str]) -> str:
    peer = request.client.host if request.client else "unknown"
    try:
        peer_ip = ipaddress.ip_address(peer)
    except ValueError:
        return peer
    trusted = _networks(trusted_proxy_cidrs)
    if trusted and any(peer_ip in network for network in trusted):
        forwarded = request.headers.get("x-forwarded-for", "")
        first = forwarded.split(",", 1)[0].strip()
        if first:
            try:
                ipaddress.ip_address(first)
            except ValueError:
                logger.warning("invalid x-forwarded-for value from trusted proxy")
            else:
                return first
    return peer


def effective_scheme(request: Request, trusted_proxy_cidrs: Sequence[str]) -> str:
    peer = request.client.host if request.client else ""
    try:
        peer_ip = ipaddress.ip_address(peer)
    except ValueError:
        peer_ip = None
    trusted = _networks(trusted_proxy_cidrs)
    if peer_ip is not None and trusted and any(peer_ip in network for network in trusted):
        forwarded_proto = request.headers.get("x-forwarded-proto", "").split(",", 1)[0].strip()
        if forwarded_proto in {"http", "https"}:
            return forwarded_proto
    return request.url.scheme


class RequestIdMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp, header_name: str = "X-Request-ID") -> None:
        super().__init__(app)
        self.header_name = header_name

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        supplied = request.headers.get(self.header_name, "").strip()
        request_id = supplied if _REQUEST_ID_RE.fullmatch(supplied) else uuid.uuid4().hex
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers[self.header_name] = request_id
        return response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp, settings: AppSettings) -> None:
        super().__init__(app)
        self.settings = settings

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        scheme = effective_scheme(request, self.settings.trusted_proxy_cidrs)
        if self.settings.force_https and scheme != "https":
            return JSONResponse(
                status_code=400,
                content={
                    "error": {
                        "code": "VALIDATION_ERROR",
                        "message": "HTTPS is required",
                        "request_id": str(getattr(request.state, "request_id", "unknown")),
                        "retryable": False,
                        "details": {},
                    }
                },
            )

        response = await call_next(request)
        if not self.settings.security_headers_enabled:
            return response

        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        response.headers.setdefault(
            "Permissions-Policy",
            "camera=(), microphone=(), geolocation=(), payment=()",
        )
        response.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
        )
        response.headers.setdefault("Cross-Origin-Resource-Policy", "same-site")
        if scheme == "https":
            response.headers.setdefault(
                "Strict-Transport-Security",
                "max-age=31536000; includeSubDomains",
            )
        if request.url.path.startswith(
            ("/v1/auth", "/v1/me", "/v1/credits", "/v1/billing", "/v1/admin", "/metrics")
        ):
            response.headers.setdefault("Cache-Control", "no-store")
        return response


class GlobalRateLimitMiddleware(BaseHTTPMiddleware):
    _EXEMPT_PREFIXES = (
        "/health/",
        "/metrics",
        "/v1/webhooks/payments/",
    )

    def __init__(self, app: ASGIApp, settings: AppSettings) -> None:
        super().__init__(app)
        self.settings = settings

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        if (
            self.settings.api_rate_limit <= 0
            or request.method == "OPTIONS"
            or request.url.path.startswith(self._EXEMPT_PREFIXES)
        ):
            return await call_next(request)
        limiter = getattr(request.app.state, "rate_limiter", None)
        if limiter is None:
            return JSONResponse(
                status_code=503,
                content={
                    "error": {
                        "code": "SERVICE_UNAVAILABLE",
                        "message": "Rate limiter is unavailable",
                        "request_id": str(getattr(request.state, "request_id", "unknown")),
                        "retryable": True,
                        "details": {},
                    }
                },
            )
        identifier = client_ip(request, self.settings.trusted_proxy_cidrs)
        try:
            await limiter.hit(
                scope="api",
                identifier=identifier,
                limit=self.settings.api_rate_limit,
                window_seconds=self.settings.api_rate_window_seconds,
            )
        except ApplicationError as exc:
            if exc.code == "RATE_LIMITED":
                await _record_rate_limit_signal(request, identifier)
            return JSONResponse(
                status_code=exc.status_code,
                content={
                    "error": {
                        "code": exc.code,
                        "message": exc.message,
                        "request_id": str(getattr(request.state, "request_id", "unknown")),
                        "retryable": exc.retryable,
                        "details": dict(exc.details or {}),
                    }
                },
            )
        except Exception:
            logger.exception("global rate limiter unavailable")
            return JSONResponse(
                status_code=503,
                content={
                    "error": {
                        "code": "SERVICE_UNAVAILABLE",
                        "message": "Rate limiter is unavailable",
                        "request_id": str(getattr(request.state, "request_id", "unknown")),
                        "retryable": True,
                        "details": {},
                    }
                },
            )
        return await call_next(request)
