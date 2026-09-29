from __future__ import annotations

import json
import logging
import re
from datetime import UTC, datetime
from typing import Any

from config import get_settings

_REDACTED = "[REDACTED]"
_SENSITIVE_KEY = (
    r"authorization|cookie|cookies|sessionid|session_ss|token|access_token|"
    r"refresh_token|api_key|api_hash|bot_token|password|secret|client_secret"
)
_REDACTION_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s,;]+"), rf"\1{_REDACTED}"),
    (
        re.compile(
            rf"(?i)([\"']?(?:{_SENSITIVE_KEY})[\"']?\s*[:=]\s*[\"']?)"
            r"([^\"'\s,;&}]+)"
        ),
        rf"\1{_REDACTED}",
    ),
    (re.compile(r"(?i)(https?://[^:/\s]+:)([^@\s/]+)(@)"), rf"\1{_REDACTED}\3"),
)


def redact_secrets(value: str) -> str:
    redacted = value
    for pattern, replacement in _REDACTION_PATTERNS:
        redacted = pattern.sub(replacement, redacted)
    return redacted


class RedactingFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return redact_secrets(super().format(record))


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": redact_secrets(record.getMessage()),
        }
        if record.exc_info:
            payload["exception"] = redact_secrets(self.formatException(record.exc_info))
        request_id = getattr(record, "request_id", None)
        if request_id is not None:
            payload["request_id"] = redact_secrets(str(request_id))
        event = getattr(record, "event", None)
        if event is not None:
            payload["event"] = redact_secrets(str(event))
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


class LoggerManager:
    _instance: "LoggerManager | None" = None
    logger: logging.Logger

    def __new__(cls) -> "LoggerManager":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance.logger = logging.getLogger("savestream.recorder")
            cls._instance.setup_logger()
        return cls._instance

    def setup_logger(self) -> None:
        settings = get_settings()
        self.logger.setLevel(settings.log_level)
        self.logger.propagate = False
        self.logger.handlers.clear()

        handler = logging.StreamHandler()
        handler.setLevel(settings.log_level)
        if settings.log_format == "json":
            handler.setFormatter(JsonFormatter())
        else:
            handler.setFormatter(
                RedactingFormatter(
                    "%(asctime)s %(levelname)s %(name)s - %(message)s",
                    "%Y-%m-%d %H:%M:%S",
                )
            )
        self.logger.addHandler(handler)


logger = LoggerManager().logger
