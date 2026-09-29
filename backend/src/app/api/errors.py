from __future__ import annotations

import logging
from typing import Any, Mapping

from fastapi import FastAPI, HTTPException, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

logger = logging.getLogger("savestream.api")


class AppError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        status_code: int = 400,
        retryable: bool = False,
        details: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.retryable = retryable
        self.details = dict(details or {})


def _request_id(request: Request) -> str:
    return str(getattr(request.state, "request_id", "unknown"))


def error_response(
    request: Request,
    *,
    code: str,
    message: str,
    status_code: int,
    retryable: bool = False,
    details: Mapping[str, Any] | None = None,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "code": code,
                "message": message,
                "request_id": _request_id(request),
                "retryable": retryable,
                "details": jsonable_encoder(dict(details or {})),
            }
        },
    )


def install_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        return error_response(
            request,
            code=exc.code,
            message=exc.message,
            status_code=exc.status_code,
            retryable=exc.retryable,
            details=exc.details,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return error_response(
            request,
            code="VALIDATION_ERROR",
            message="Request validation failed",
            status_code=400,
            details={"errors": exc.errors()},
        )

    @app.exception_handler(HTTPException)
    async def handle_http_error(request: Request, exc: HTTPException) -> JSONResponse:
        code_by_status = {
            400: "VALIDATION_ERROR",
            401: "AUTH_SESSION_REVOKED",
            403: "FORBIDDEN",
            404: "RESOURCE_NOT_FOUND",
            409: "VALIDATION_ERROR",
            429: "RATE_LIMITED",
            503: "SERVICE_UNAVAILABLE",
        }
        code = code_by_status.get(exc.status_code, "INTERNAL_ERROR")
        return error_response(
            request,
            code=code,
            message=str(exc.detail),
            status_code=exc.status_code,
            retryable=exc.status_code >= 500,
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled API error request_id=%s", _request_id(request), exc_info=exc)
        return error_response(
            request,
            code="INTERNAL_ERROR",
            message="Internal server error",
            status_code=500,
            retryable=True,
        )
