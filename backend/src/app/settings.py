from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Literal, cast

Environment = Literal["local", "test", "staging", "production"]


def _env(name: str, default: str) -> str:
    return os.getenv(f"SAVESTREAM_{name}", default).strip()


def _bool_env(name: str, default: bool) -> bool:
    raw = _env(name, "true" if default else "false").lower()
    if raw in {"1", "true", "yes", "on"}:
        return True
    if raw in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"SAVESTREAM_{name} must be a boolean")


def _float_env(name: str, default: float) -> float:
    value = float(_env(name, str(default)))
    if value <= 0:
        raise ValueError(f"SAVESTREAM_{name} must be greater than zero")
    return value


def _int_env(name: str, default: int) -> int:
    value = int(_env(name, str(default)))
    if value <= 0:
        raise ValueError(f"SAVESTREAM_{name} must be greater than zero")
    return value


def _csv_env(name: str, default: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in _env(name, default).split(",") if item.strip())


@dataclass(frozen=True, slots=True)
class AppSettings:
    environment: Environment
    database_url: str
    redis_url: str
    celery_broker_url: str
    celery_result_backend: str
    minio_endpoint: str
    minio_access_key: str = field(repr=False)
    minio_secret_key: str = field(repr=False)
    jwt_secret: str = field(default="savestream-dev-only-change-me", repr=False)
    minio_bucket: str = "savestream-recordings"
    minio_secure: bool = False
    cors_allow_origins: tuple[str, ...] = ()
    request_id_header: str = "X-Request-ID"
    dependency_timeout_seconds: float = 2.0
    outbox_poll_seconds: float = 1.0
    jwt_issuer: str = "savestream"
    jwt_audience: str = "savestream-clients"
    access_token_ttl_seconds: int = 900
    refresh_token_ttl_seconds: int = 2_592_000
    one_time_token_ttl_seconds: int = 1_800
    refresh_cookie_name: str = "savestream_refresh"
    frontend_base_url: str = "http://localhost:5173"
    smtp_host: str = "localhost"
    smtp_port: int = 1025
    email_from: str = "SaveStream <no-reply@savestream.local>"
    login_rate_limit: int = 5
    login_rate_window_seconds: int = 60
    auth_write_rate_limit: int = 5
    auth_write_rate_window_seconds: int = 3600

    @classmethod
    def from_env(cls) -> "AppSettings":
        environment_raw = _env("ENVIRONMENT", "local").lower()
        if environment_raw not in {"local", "test", "staging", "production"}:
            raise ValueError(
                "SAVESTREAM_ENVIRONMENT must be one of local, test, staging, production"
            )

        redis_url = _env("REDIS_URL", "redis://localhost:6379/0")
        origins = _csv_env(
            "CORS_ALLOW_ORIGINS",
            "http://localhost:3000,http://localhost:5173,http://localhost:8080",
        )
        if "*" in origins:
            raise ValueError("Wildcard CORS origins are not allowed")

        jwt_secret = _env("JWT_SECRET", "savestream-dev-only-change-me")
        if environment_raw == "production" and jwt_secret == "savestream-dev-only-change-me":
            raise ValueError("SAVESTREAM_JWT_SECRET must be configured in production")

        return cls(
            environment=cast(Environment, environment_raw),
            database_url=_env(
                "DATABASE_URL",
                "postgresql+asyncpg://savestream:savestream@localhost:5432/savestream",
            ),
            redis_url=redis_url,
            celery_broker_url=_env("CELERY_BROKER_URL", redis_url),
            celery_result_backend=_env("CELERY_RESULT_BACKEND", redis_url),
            minio_endpoint=_env("MINIO_ENDPOINT", "http://localhost:9000"),
            minio_access_key=_env("MINIO_ACCESS_KEY", "savestream"),
            minio_secret_key=_env("MINIO_SECRET_KEY", "savestream-local-only"),
            jwt_secret=jwt_secret,
            minio_bucket=_env("MINIO_BUCKET", "savestream-recordings"),
            minio_secure=_bool_env("MINIO_SECURE", False),
            cors_allow_origins=origins,
            request_id_header=_env("REQUEST_ID_HEADER", "X-Request-ID"),
            dependency_timeout_seconds=_float_env("DEPENDENCY_TIMEOUT_SECONDS", 2.0),
            outbox_poll_seconds=_float_env("OUTBOX_POLL_SECONDS", 1.0),
            jwt_issuer=_env("JWT_ISSUER", "savestream"),
            jwt_audience=_env("JWT_AUDIENCE", "savestream-clients"),
            access_token_ttl_seconds=_int_env("ACCESS_TOKEN_TTL_SECONDS", 900),
            refresh_token_ttl_seconds=_int_env("REFRESH_TOKEN_TTL_SECONDS", 2_592_000),
            one_time_token_ttl_seconds=_int_env("ONE_TIME_TOKEN_TTL_SECONDS", 1_800),
            refresh_cookie_name=_env("REFRESH_COOKIE_NAME", "savestream_refresh"),
            frontend_base_url=_env("FRONTEND_BASE_URL", "http://localhost:5173").rstrip("/"),
            smtp_host=_env("SMTP_HOST", "localhost"),
            smtp_port=_int_env("SMTP_PORT", 1025),
            email_from=_env("EMAIL_FROM", "SaveStream <no-reply@savestream.local>"),
            login_rate_limit=_int_env("LOGIN_RATE_LIMIT", 5),
            login_rate_window_seconds=_int_env("LOGIN_RATE_WINDOW_SECONDS", 60),
            auth_write_rate_limit=_int_env("AUTH_WRITE_RATE_LIMIT", 5),
            auth_write_rate_window_seconds=_int_env("AUTH_WRITE_RATE_WINDOW_SECONDS", 3600),
        )


@lru_cache(maxsize=1)
def get_app_settings() -> AppSettings:
    return AppSettings.from_env()
