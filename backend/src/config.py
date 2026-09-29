from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Literal, cast

Environment = Literal["local", "test", "staging", "production"]
LogFormat = Literal["json", "console"]


class SettingsError(ValueError):
    """Raised when an environment setting cannot be parsed safely."""


def _env(name: str, default: str) -> str:
    return os.getenv(f"SAVESTREAM_{name}", default).strip()


def _positive_float(name: str, default: float) -> float:
    raw = _env(name, str(default))
    try:
        value = float(raw)
    except ValueError as exc:
        raise SettingsError(f"SAVESTREAM_{name} must be a number") from exc
    if value <= 0:
        raise SettingsError(f"SAVESTREAM_{name} must be greater than zero")
    return value


def _optional_path(name: str) -> Path | None:
    raw = _env(name, "")
    return Path(raw).expanduser() if raw else None


@dataclass(frozen=True, slots=True)
class Settings:
    environment: Environment
    log_level: int
    log_format: LogFormat
    http_timeout_seconds: float
    http_stream_timeout_seconds: float
    proxy_check_timeout_seconds: float
    update_timeout_seconds: float
    cookies_file: Path | None
    telegram_config_file: Path | None

    @classmethod
    def from_env(cls) -> "Settings":
        environment_raw = _env("ENVIRONMENT", "local").lower()
        if environment_raw not in {"local", "test", "staging", "production"}:
            raise SettingsError(
                "SAVESTREAM_ENVIRONMENT must be one of: local, test, staging, production"
            )

        log_format_raw = _env("LOG_FORMAT", "json").lower()
        if log_format_raw not in {"json", "console"}:
            raise SettingsError("SAVESTREAM_LOG_FORMAT must be 'json' or 'console'")

        log_level_name = _env("LOG_LEVEL", "INFO").upper()
        log_level = logging.getLevelNamesMapping().get(log_level_name)
        if not isinstance(log_level, int):
            raise SettingsError(
                "SAVESTREAM_LOG_LEVEL must be a standard Python logging level"
            )

        return cls(
            environment=cast(Environment, environment_raw),
            log_level=log_level,
            log_format=cast(LogFormat, log_format_raw),
            http_timeout_seconds=_positive_float("HTTP_TIMEOUT_SECONDS", 15.0),
            http_stream_timeout_seconds=_positive_float(
                "HTTP_STREAM_TIMEOUT_SECONDS", 30.0
            ),
            proxy_check_timeout_seconds=_positive_float(
                "PROXY_CHECK_TIMEOUT_SECONDS", 10.0
            ),
            update_timeout_seconds=_positive_float("UPDATE_TIMEOUT_SECONDS", 15.0),
            cookies_file=_optional_path("COOKIES_FILE"),
            telegram_config_file=_optional_path("TELEGRAM_CONFIG_FILE"),
        )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings.from_env()
