from __future__ import annotations

import os
from pathlib import Path
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Literal, cast
from urllib.parse import urlparse

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


def _nonnegative_int_env(name: str, default: int) -> int:
    value = int(_env(name, str(default)))
    if value < 0:
        raise ValueError(f"SAVESTREAM_{name} must be zero or greater")
    return value


def _secret_env(name: str, default: str) -> str:
    direct_key = f"SAVESTREAM_{name}"
    file_key = f"{direct_key}_FILE"
    direct = os.getenv(direct_key)
    file_path = os.getenv(file_key, "").strip()
    if direct is not None and file_path:
        raise ValueError(f"{direct_key} and {file_key} cannot both be set")
    if file_path:
        value = Path(file_path).read_text(encoding="utf-8").strip()
        if not value:
            raise ValueError(f"{file_key} points to an empty secret")
        return value
    return direct.strip() if direct is not None else default


def _csv_env(name: str, default: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in _env(name, default).split(",") if item.strip())


def _exact_origin(value: str, setting_name: str) -> str:
    parsed = urlparse(value)
    if (
        parsed.scheme not in {"http", "https"}
        or not parsed.netloc
        or parsed.username
        or parsed.password
        or parsed.path not in {"", "/"}
        or parsed.params
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError(
            f"{setting_name} must be an exact http(s) origin without path, credentials, query, or fragment"
        )
    return f"{parsed.scheme}://{parsed.netloc}"


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
    jwt_previous_secrets: tuple[str, ...] = field(default=(), repr=False)
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
    smtp_username: str = field(default="", repr=False)
    smtp_password: str = field(default="", repr=False)
    smtp_starttls: bool = False
    email_from: str = "SaveStream <no-reply@savestream.local>"
    login_rate_limit: int = 5
    login_rate_window_seconds: int = 60
    auth_write_rate_limit: int = 5
    auth_write_rate_window_seconds: int = 3600
    recording_temp_dir: str = "/tmp/savestream-recordings"
    recording_max_duration_seconds: int = 14_400
    recording_heartbeat_seconds: int = 10
    recording_stale_after_seconds: int = 60
    recording_queue: str = "celery"
    recording_max_attempts: int = 3
    artifact_presign_seconds: int = 900
    sse_poll_seconds: float = 1.0
    idempotency_ttl_seconds: int = 86_400
    watch_scheduler_tick_seconds: int = 15
    watch_scheduler_batch_size: int = 50
    watch_scheduler_lease_seconds: int = 90
    watch_offline_check_seconds: int = 60
    watch_live_check_seconds: int = 20
    watch_error_backoff_base_seconds: int = 30
    watch_error_backoff_max_seconds: int = 900
    watch_error_pause_threshold: int = 5
    watch_jitter_ratio: float = 0.2
    watch_max_concurrent_recordings_per_user: int = 2
    payment_provider: str = "fake"
    payment_provider_base_url: str = ""
    payment_provider_api_key: str = field(default="", repr=False)
    payment_webhook_secret: str = field(default="savestream-fake-payment-secret", repr=False)
    lemon_squeezy_store_id: str = ""
    lemon_squeezy_variant_id: str = ""
    payment_timeout_seconds: float = 15.0
    payment_reconcile_seconds: int = 300
    metrics_token: str = field(default="savestream-local-metrics", repr=False)
    ops_alert_email: str = ""
    ops_alert_check_seconds: int = 60
    ops_alert_cooldown_seconds: int = 1800
    ops_failed_recording_window_seconds: int = 900
    ops_outbox_alert_threshold: int = 100
    ops_failed_recording_alert_threshold: int = 10
    ops_payment_event_alert_threshold: int = 10
    ops_paused_watch_alert_threshold: int = 20
    api_rate_limit: int = 0
    api_rate_window_seconds: int = 60
    trusted_proxy_cidrs: tuple[str, ...] = ()
    force_https: bool = False
    security_headers_enabled: bool = True
    quota_max_watches_per_user: int = 0
    quota_max_recordings_per_day: int = 0
    quota_max_active_recordings_per_user: int = 0
    recording_retention_days: int = 0
    recording_retention_days_free: int = 0
    signup_credits: int = 0
    account_deletion_grace_days: int = 0
    retention_check_seconds: int = 3600
    recording_source_backend: str = "tiktok"
    e2e_stream_base_url: str = ""
    push_provider: str = "noop"
    push_fcm_service_account_json: str = field(default="", repr=False)
    push_fcm_base_url: str = "https://fcm.googleapis.com"
    push_fcm_token_url: str = "https://oauth2.googleapis.com/token"
    push_timeout_seconds: float = 10.0
    store_purchase_provider: str = "disabled"
    app_store_bundle_id: str = ""
    app_store_issuer_id: str = ""
    app_store_key_id: str = ""
    app_store_private_key: str = field(default="", repr=False)
    app_store_root_certificates_json: str = field(default="", repr=False)
    app_store_app_apple_id: int = 0
    app_store_environment: str = "sandbox"
    google_play_package_name: str = ""
    google_play_service_account_json: str = field(default="", repr=False)
    google_play_rtdn_audience: str = ""
    google_play_rtdn_service_account_email: str = ""
    store_purchase_timeout_seconds: float = 15.0

    @classmethod
    def from_env(cls) -> "AppSettings":
        environment_raw = _env("ENVIRONMENT", "local").lower()
        if environment_raw not in {"local", "test", "staging", "production"}:
            raise ValueError(
                "SAVESTREAM_ENVIRONMENT must be one of local, test, staging, production"
            )
        redis_url = _secret_env("REDIS_URL", "redis://localhost:6379/0")
        origins = _csv_env(
            "CORS_ALLOW_ORIGINS",
            "http://localhost:3000,http://localhost:5173,http://localhost:8080",
        )
        if "*" in origins:
            raise ValueError("Wildcard CORS origins are not allowed")
        for origin in origins:
            if _exact_origin(origin, "SAVESTREAM_CORS_ALLOW_ORIGINS") != origin:
                raise ValueError(
                    "SAVESTREAM_CORS_ALLOW_ORIGINS entries must be exact origins without a trailing slash"
                )
        jwt_secret = _secret_env("JWT_SECRET", "savestream-dev-only-change-me")
        jwt_previous_secrets = tuple(
            item.strip()
            for item in _secret_env("JWT_PREVIOUS_SECRETS", "").split(",")
            if item.strip()
        )
        if environment_raw == "production" and jwt_secret == "savestream-dev-only-change-me":
            raise ValueError("SAVESTREAM_JWT_SECRET must be configured in production")
        payment_provider = _env("PAYMENT_PROVIDER", "fake").lower()
        payment_provider_base_url = _env(
            "PAYMENT_PROVIDER_BASE_URL",
            (
                "https://api.lemonsqueezy.com/v1"
                if payment_provider == "lemonsqueezy"
                else ""
            ),
        ).rstrip("/")
        payment_provider_api_key = _secret_env("PAYMENT_PROVIDER_API_KEY", "")
        payment_webhook_secret = _secret_env(
            "PAYMENT_WEBHOOK_SECRET",
            "savestream-fake-payment-secret",
        )
        lemon_squeezy_store_id = _env("LEMON_SQUEEZY_STORE_ID", "")
        lemon_squeezy_variant_id = _env("LEMON_SQUEEZY_VARIANT_ID", "")
        smtp_host = _env("SMTP_HOST", "localhost")
        smtp_port = _int_env("SMTP_PORT", 1025)
        smtp_username = _secret_env("SMTP_USERNAME", "")
        smtp_password = _secret_env("SMTP_PASSWORD", "")
        smtp_starttls = _bool_env("SMTP_STARTTLS", False)
        email_from = _env("EMAIL_FROM", "SaveStream <no-reply@savestream.local>")
        if payment_provider == "lemonsqueezy" and not (
            6 <= len(payment_webhook_secret) <= 40
        ):
            raise ValueError(
                "Lemon Squeezy webhook secret must be 6 to 40 characters"
            )
        metrics_token = _secret_env("METRICS_TOKEN", "savestream-local-metrics")
        trusted_proxy_cidrs = _csv_env("TRUSTED_PROXY_CIDRS", "")
        force_https = _bool_env("FORCE_HTTPS", environment_raw == "production")
        api_rate_limit = _nonnegative_int_env("API_RATE_LIMIT", 300)
        quota_max_watches = _nonnegative_int_env("QUOTA_MAX_WATCHES_PER_USER", 100)
        quota_max_recordings_day = _nonnegative_int_env(
            "QUOTA_MAX_RECORDINGS_PER_DAY", 100
        )
        quota_max_active_recordings = _nonnegative_int_env(
            "QUOTA_MAX_ACTIVE_RECORDINGS_PER_USER", 2
        )
        frontend_base_url = _env(
            "FRONTEND_BASE_URL", "http://localhost:5173"
        ).rstrip("/")
        recording_source_backend = _env("RECORDING_SOURCE_BACKEND", "tiktok").lower()
        e2e_stream_base_url = _env("E2E_STREAM_BASE_URL", "").rstrip("/")
        push_provider = _env("PUSH_PROVIDER", "noop").lower()
        if push_provider not in {"noop", "fcm"}:
            raise ValueError("SAVESTREAM_PUSH_PROVIDER must be one of noop, fcm")
        push_fcm_service_account_json = _secret_env(
            "PUSH_FCM_SERVICE_ACCOUNT_JSON",
            "",
        )
        push_fcm_base_url = _env(
            "PUSH_FCM_BASE_URL",
            "https://fcm.googleapis.com",
        ).rstrip("/")
        push_fcm_token_url = _env(
            "PUSH_FCM_TOKEN_URL",
            "https://oauth2.googleapis.com/token",
        )
        push_timeout_seconds = _float_env("PUSH_TIMEOUT_SECONDS", 10.0)
        store_purchase_provider = _env(
            "STORE_PURCHASE_PROVIDER",
            "disabled",
        ).lower()
        if store_purchase_provider not in {"disabled", "fake", "live"}:
            raise ValueError(
                "SAVESTREAM_STORE_PURCHASE_PROVIDER must be one of "
                "disabled, fake, live"
            )
        app_store_bundle_id = _env("APP_STORE_BUNDLE_ID", "")
        app_store_issuer_id = _env("APP_STORE_ISSUER_ID", "")
        app_store_key_id = _env("APP_STORE_KEY_ID", "")
        app_store_private_key = _secret_env("APP_STORE_PRIVATE_KEY", "")
        app_store_root_certificates_json = _secret_env(
            "APP_STORE_ROOT_CERTIFICATES_JSON",
            "",
        )
        app_store_app_apple_id = _nonnegative_int_env(
            "APP_STORE_APP_APPLE_ID",
            0,
        )
        app_store_environment = _env(
            "APP_STORE_ENVIRONMENT",
            "sandbox",
        ).lower()
        if app_store_environment not in {"sandbox", "production"}:
            raise ValueError(
                "SAVESTREAM_APP_STORE_ENVIRONMENT must be sandbox or production"
            )
        google_play_package_name = _env("GOOGLE_PLAY_PACKAGE_NAME", "")
        google_play_service_account_json = _secret_env(
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
            "",
        )
        google_play_rtdn_audience = _env(
            "GOOGLE_PLAY_RTDN_AUDIENCE",
            "",
        )
        google_play_rtdn_service_account_email = _env(
            "GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL",
            "",
        )
        store_purchase_timeout_seconds = _float_env(
            "STORE_PURCHASE_TIMEOUT_SECONDS",
            15.0,
        )
        if push_provider == "fcm" and not push_fcm_service_account_json:
            raise ValueError(
                "SAVESTREAM_PUSH_FCM_SERVICE_ACCOUNT_JSON is required when "
                "SAVESTREAM_PUSH_PROVIDER=fcm"
            )
        if recording_source_backend not in {"tiktok", "fake_http"}:
            raise ValueError(
                "SAVESTREAM_RECORDING_SOURCE_BACKEND must be one of tiktok, fake_http"
            )
        if recording_source_backend == "fake_http" and not e2e_stream_base_url:
            raise ValueError(
                "SAVESTREAM_E2E_STREAM_BASE_URL is required for fake_http recording backend"
            )
        if environment_raw == "production":
            if store_purchase_provider == "fake":
                raise ValueError(
                    "SAVESTREAM_STORE_PURCHASE_PROVIDER cannot be fake in production"
                )
            if store_purchase_provider == "live" and (
                not app_store_bundle_id
                or not app_store_issuer_id
                or not app_store_key_id
                or not app_store_private_key
                or not app_store_root_certificates_json
                or app_store_app_apple_id <= 0
                or not google_play_package_name
                or not google_play_service_account_json
                or not google_play_rtdn_audience
                or not google_play_rtdn_service_account_email
            ):
                raise ValueError(
                    "Apple and Google store credentials must be configured "
                    "when SAVESTREAM_STORE_PURCHASE_PROVIDER=live in production"
                )
            if push_provider == "fcm" and (
                not push_fcm_base_url.startswith("https://")
                or not push_fcm_token_url.startswith("https://")
            ):
                raise ValueError("FCM endpoints must use https in production")
            if recording_source_backend != "tiktok":
                raise ValueError(
                    "SAVESTREAM_RECORDING_SOURCE_BACKEND must be tiktok in production"
                )
            if payment_provider == "fake":
                raise ValueError("SAVESTREAM_PAYMENT_PROVIDER cannot be fake in production")
            # "disabled" launches without a payment provider; checkout fails closed.
            if payment_provider != "disabled":
                if not payment_provider_base_url:
                    raise ValueError(
                        "SAVESTREAM_PAYMENT_PROVIDER_BASE_URL must be configured in production"
                    )
                if not payment_provider_base_url.startswith("https://"):
                    raise ValueError(
                        "SAVESTREAM_PAYMENT_PROVIDER_BASE_URL must use https in production"
                    )
                if not payment_provider_api_key or payment_provider_api_key == "payments-disabled":
                    raise ValueError(
                        "SAVESTREAM_PAYMENT_PROVIDER_API_KEY must be configured in production"
                    )
                if payment_webhook_secret == "savestream-fake-payment-secret":
                    raise ValueError(
                        "SAVESTREAM_PAYMENT_WEBHOOK_SECRET must be configured in production"
                    )
                if payment_provider == "lemonsqueezy" and (
                    not lemon_squeezy_store_id or not lemon_squeezy_variant_id
                ):
                    raise ValueError(
                        "Lemon Squeezy store and variant IDs must be configured in production"
                    )
            if (
                smtp_host in {"localhost", "mail-debug"}
                or not smtp_username
                or not smtp_password
                or not smtp_starttls
            ):
                raise ValueError(
                    "Authenticated STARTTLS SMTP must be configured in production"
                )
            if "savestream.local" in email_from:
                raise ValueError(
                    "SAVESTREAM_EMAIL_FROM must be configured in production"
                )
            if metrics_token == "savestream-local-metrics":
                raise ValueError(
                    "SAVESTREAM_METRICS_TOKEN must be configured in production"
                )
            if len(jwt_secret) < 32:
                raise ValueError("SAVESTREAM_JWT_SECRET must be at least 32 characters")
            if jwt_secret in jwt_previous_secrets:
                raise ValueError(
                    "SAVESTREAM_JWT_PREVIOUS_SECRETS must not include the current JWT secret"
                )
            if not trusted_proxy_cidrs:
                raise ValueError(
                    "SAVESTREAM_TRUSTED_PROXY_CIDRS must be configured in production"
                )
            if not force_https:
                raise ValueError("SAVESTREAM_FORCE_HTTPS must be enabled in production")
            if api_rate_limit <= 0:
                raise ValueError("SAVESTREAM_API_RATE_LIMIT must be enabled in production")
            if (
                quota_max_watches <= 0
                or quota_max_recordings_day <= 0
                or quota_max_active_recordings <= 0
            ):
                raise ValueError("Production quotas must be explicitly enabled")
            if not frontend_base_url.startswith("https://"):
                raise ValueError(
                    "SAVESTREAM_FRONTEND_BASE_URL must use https in production"
                )
            frontend_origin = _exact_origin(
                frontend_base_url,
                "SAVESTREAM_FRONTEND_BASE_URL",
            )
            if frontend_origin != frontend_base_url:
                raise ValueError(
                    "SAVESTREAM_FRONTEND_BASE_URL must be an exact origin without a trailing slash"
                )
            if frontend_origin not in origins:
                raise ValueError(
                    "Production CORS origins must include SAVESTREAM_FRONTEND_BASE_URL"
                )
            if not origins:
                raise ValueError(
                    "SAVESTREAM_CORS_ALLOW_ORIGINS must be configured in production"
                )
            for origin in origins:
                if not origin.startswith("https://") or "localhost" in origin:
                    raise ValueError(
                        "Production CORS origins must use https and cannot target localhost"
                    )
            if not _bool_env("SECURITY_HEADERS_ENABLED", True):
                raise ValueError(
                    "SAVESTREAM_SECURITY_HEADERS_ENABLED must be enabled in production"
                )

        return cls(
            environment=cast(Environment, environment_raw),
            database_url=_secret_env(
                "DATABASE_URL",
                "postgresql+asyncpg://savestream:savestream@localhost:5432/savestream",
            ),
            redis_url=redis_url,
            celery_broker_url=_secret_env("CELERY_BROKER_URL", redis_url),
            celery_result_backend=_secret_env("CELERY_RESULT_BACKEND", redis_url),
            minio_endpoint=_env("MINIO_ENDPOINT", "http://localhost:9000"),
            minio_access_key=_secret_env("MINIO_ACCESS_KEY", "savestream"),
            minio_secret_key=_secret_env("MINIO_SECRET_KEY", "savestream-local-only"),
            jwt_secret=jwt_secret,
            jwt_previous_secrets=jwt_previous_secrets,
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
            frontend_base_url=frontend_base_url,
            smtp_host=smtp_host,
            smtp_port=smtp_port,
            smtp_username=smtp_username,
            smtp_password=smtp_password,
            smtp_starttls=smtp_starttls,
            email_from=email_from,
            login_rate_limit=_int_env("LOGIN_RATE_LIMIT", 5),
            login_rate_window_seconds=_int_env("LOGIN_RATE_WINDOW_SECONDS", 60),
            auth_write_rate_limit=_int_env("AUTH_WRITE_RATE_LIMIT", 5),
            auth_write_rate_window_seconds=_int_env("AUTH_WRITE_RATE_WINDOW_SECONDS", 3600),
            recording_temp_dir=_env("RECORDING_TEMP_DIR", "/tmp/savestream-recordings"),
            recording_max_duration_seconds=_int_env("RECORDING_MAX_DURATION_SECONDS", 14_400),
            recording_heartbeat_seconds=_int_env("RECORDING_HEARTBEAT_SECONDS", 10),
            recording_stale_after_seconds=_int_env("RECORDING_STALE_AFTER_SECONDS", 60),
            recording_queue=_env("RECORDING_QUEUE", "celery").strip() or "celery",
            recording_max_attempts=_int_env("RECORDING_MAX_ATTEMPTS", 3),
            artifact_presign_seconds=_int_env("ARTIFACT_PRESIGN_SECONDS", 900),
            sse_poll_seconds=_float_env("SSE_POLL_SECONDS", 1.0),
            idempotency_ttl_seconds=_int_env("IDEMPOTENCY_TTL_SECONDS", 86_400),
            watch_scheduler_tick_seconds=_int_env("WATCH_SCHEDULER_TICK_SECONDS", 15),
            watch_scheduler_batch_size=_int_env("WATCH_SCHEDULER_BATCH_SIZE", 50),
            watch_scheduler_lease_seconds=_int_env("WATCH_SCHEDULER_LEASE_SECONDS", 90),
            watch_offline_check_seconds=_int_env("WATCH_OFFLINE_CHECK_SECONDS", 60),
            watch_live_check_seconds=_int_env("WATCH_LIVE_CHECK_SECONDS", 20),
            watch_error_backoff_base_seconds=_int_env(
                "WATCH_ERROR_BACKOFF_BASE_SECONDS", 30
            ),
            watch_error_backoff_max_seconds=_int_env(
                "WATCH_ERROR_BACKOFF_MAX_SECONDS", 900
            ),
            watch_error_pause_threshold=_int_env("WATCH_ERROR_PAUSE_THRESHOLD", 5),
            watch_jitter_ratio=_float_env("WATCH_JITTER_RATIO", 0.2),
            watch_max_concurrent_recordings_per_user=_int_env(
                "WATCH_MAX_CONCURRENT_RECORDINGS_PER_USER", 2
            ),
            payment_provider=payment_provider,
            payment_provider_base_url=payment_provider_base_url,
            payment_provider_api_key=payment_provider_api_key,
            payment_webhook_secret=payment_webhook_secret,
            lemon_squeezy_store_id=lemon_squeezy_store_id,
            lemon_squeezy_variant_id=lemon_squeezy_variant_id,
            payment_timeout_seconds=_float_env("PAYMENT_TIMEOUT_SECONDS", 15.0),
            payment_reconcile_seconds=_int_env("PAYMENT_RECONCILE_SECONDS", 300),
            metrics_token=metrics_token,
            ops_alert_email=_env("OPS_ALERT_EMAIL", ""),
            ops_alert_check_seconds=_int_env("OPS_ALERT_CHECK_SECONDS", 60),
            ops_alert_cooldown_seconds=_int_env("OPS_ALERT_COOLDOWN_SECONDS", 1800),
            ops_failed_recording_window_seconds=_int_env(
                "OPS_FAILED_RECORDING_WINDOW_SECONDS", 900
            ),
            ops_outbox_alert_threshold=_int_env("OPS_OUTBOX_ALERT_THRESHOLD", 100),
            ops_failed_recording_alert_threshold=_int_env(
                "OPS_FAILED_RECORDING_ALERT_THRESHOLD", 10
            ),
            ops_payment_event_alert_threshold=_int_env(
                "OPS_PAYMENT_EVENT_ALERT_THRESHOLD", 10
            ),
            ops_paused_watch_alert_threshold=_int_env(
                "OPS_PAUSED_WATCH_ALERT_THRESHOLD", 20
            ),
            api_rate_limit=api_rate_limit,
            api_rate_window_seconds=_int_env("API_RATE_WINDOW_SECONDS", 60),
            trusted_proxy_cidrs=trusted_proxy_cidrs,
            force_https=force_https,
            security_headers_enabled=_bool_env("SECURITY_HEADERS_ENABLED", True),
            quota_max_watches_per_user=quota_max_watches,
            quota_max_recordings_per_day=quota_max_recordings_day,
            quota_max_active_recordings_per_user=quota_max_active_recordings,
            recording_retention_days=_nonnegative_int_env(
                "RECORDING_RETENTION_DAYS", 0
            ),
            recording_retention_days_free=_nonnegative_int_env(
                "RECORDING_RETENTION_DAYS_FREE", 0
            ),
            signup_credits=_nonnegative_int_env("SIGNUP_CREDITS", 0),
            account_deletion_grace_days=_nonnegative_int_env(
                "ACCOUNT_DELETION_GRACE_DAYS", 0
            ),
            retention_check_seconds=_int_env("RETENTION_CHECK_SECONDS", 3600),
            recording_source_backend=recording_source_backend,
            e2e_stream_base_url=e2e_stream_base_url,
            push_provider=push_provider,
            push_fcm_service_account_json=push_fcm_service_account_json,
            push_fcm_base_url=push_fcm_base_url,
            push_fcm_token_url=push_fcm_token_url,
            push_timeout_seconds=push_timeout_seconds,
            store_purchase_provider=store_purchase_provider,
            app_store_bundle_id=app_store_bundle_id,
            app_store_issuer_id=app_store_issuer_id,
            app_store_key_id=app_store_key_id,
            app_store_private_key=app_store_private_key,
            app_store_root_certificates_json=app_store_root_certificates_json,
            app_store_app_apple_id=app_store_app_apple_id,
            app_store_environment=app_store_environment,
            google_play_package_name=google_play_package_name,
            google_play_service_account_json=google_play_service_account_json,
            google_play_rtdn_audience=google_play_rtdn_audience,
            google_play_rtdn_service_account_email=(
                google_play_rtdn_service_account_email
            ),
            store_purchase_timeout_seconds=store_purchase_timeout_seconds,
        )


@lru_cache(maxsize=1)
def get_app_settings() -> AppSettings:
    return AppSettings.from_env()
