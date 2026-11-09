"""Settings for the downloader service.

The downloader runs in its own container with only the secrets it needs:
Redis (rate limits, short-lived media tokens, the report blocklist), the
optional egress proxy, the Turnstile secret and the grant key shared with the
API for owner downloads. It never sees the database, storage, JWT or mail
credentials, so it does not load AppSettings.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.settings import _bool_env, _csv_env, _env, _int_env, _optional_secret_env

logger = logging.getLogger(__name__)

PROVIDER_NAMES = ("page", "ytdlp")


@dataclass(frozen=True, slots=True)
class DownloaderSettings:
    environment: str = "development"
    flag_enabled: bool = False
    proxy_url: str = field(default="", repr=False)
    redis_url: str = field(default="redis://localhost:6379/0", repr=False)
    turnstile_secret_key: str = field(default="", repr=False)
    grant_secret: str = field(default="", repr=False)
    trusted_proxy_cidrs: tuple[str, ...] = ()
    # The website calls the downloader cross-origin (api. host).
    cors_allow_origins: tuple[str, ...] = ()
    frontend_base_url: str = "https://savestream.online"
    resolve_limit: int = 10
    resolve_window_seconds: int = 3600
    turnstile_after: int = 5
    max_duration_seconds: int = 600
    max_bytes: int = 300 * 1024 * 1024
    max_streams: int = 4
    token_ttl_seconds: int = 600
    providers: tuple[str, ...] = PROVIDER_NAMES

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def enabled(self) -> bool:
        """The flag, unless production has no separate egress yet: then the
        downloader would share the IP LIVE recording uses, so it stays off."""
        if not self.flag_enabled:
            return False
        if self.is_production and not self.proxy_url:
            return False
        return True

    @property
    def guard_blocked(self) -> bool:
        return self.flag_enabled and self.is_production and not self.proxy_url

    @classmethod
    def from_env(cls) -> DownloaderSettings:
        providers = tuple(
            name for name in _csv_env("VIDEO_DOWNLOADER_PROVIDERS", ",".join(PROVIDER_NAMES))
            if name in PROVIDER_NAMES
        )
        proxy_url = _optional_secret_env("VIDEO_DOWNLOADER_PROXY_URL")
        if proxy_url and not proxy_url.startswith(("http://", "https://", "socks5://", "socks5h://")):
            raise ValueError("SAVESTREAM_VIDEO_DOWNLOADER_PROXY_URL must be an http(s) or socks5 URL")
        return cls(
            environment=_env("ENVIRONMENT", "development").lower(),
            flag_enabled=_bool_env("VIDEO_DOWNLOADER_ENABLED", False),
            proxy_url=proxy_url,
            redis_url=_optional_secret_env("REDIS_URL") or "redis://localhost:6379/0",
            turnstile_secret_key=_optional_secret_env("TURNSTILE_SECRET_KEY"),
            grant_secret=_optional_secret_env("VIDEO_DOWNLOADER_GRANT_SECRET"),
            trusted_proxy_cidrs=_csv_env("TRUSTED_PROXY_CIDRS", ""),
            cors_allow_origins=_csv_env("CORS_ALLOW_ORIGINS", ""),
            frontend_base_url=_env("FRONTEND_BASE_URL", "https://savestream.online").rstrip("/"),
            resolve_limit=_int_env("VIDEO_DOWNLOADER_RESOLVE_LIMIT", 10),
            resolve_window_seconds=_int_env("VIDEO_DOWNLOADER_RESOLVE_WINDOW_SECONDS", 3600),
            turnstile_after=_int_env("VIDEO_DOWNLOADER_TURNSTILE_AFTER", 5),
            max_duration_seconds=_int_env("VIDEO_DOWNLOADER_MAX_DURATION_SECONDS", 600),
            max_bytes=_int_env("VIDEO_DOWNLOADER_MAX_BYTES", 300 * 1024 * 1024),
            max_streams=_int_env("VIDEO_DOWNLOADER_MAX_STREAMS", 4),
            token_ttl_seconds=_int_env("VIDEO_DOWNLOADER_TOKEN_TTL_SECONDS", 600),
            providers=providers or PROVIDER_NAMES,
        )


def log_startup_state(settings: DownloaderSettings) -> None:
    if settings.guard_blocked:
        logger.error(
            "VIDEO_DOWNLOADER_ENABLED is on but SAVESTREAM_VIDEO_DOWNLOADER_PROXY_URL is "
            "not set: the downloader stays OFF so it never shares the LIVE recording IP"
        )
    elif settings.enabled:
        logger.info("Video downloader enabled (egress via %s)", "proxy" if settings.proxy_url else "host IP")
    else:
        logger.info("Video downloader disabled")
