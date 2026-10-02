from __future__ import annotations

import argparse
from dataclasses import dataclass
from urllib.parse import urlparse

from app.settings import AppSettings
from config import Settings as RuntimeSettings


@dataclass(frozen=True, slots=True)
class ReleaseManifest:
    api_origin: str
    frontend_origin: str
    payment_webhook_url: str
    allow_disabled_payments: bool = False


def _origin(value: str, name: str) -> str:
    parsed = urlparse(value)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username
        or parsed.password
        or parsed.path not in {"", "/"}
        or parsed.params
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError(f"{name} must be an exact HTTPS origin")
    return f"{parsed.scheme}://{parsed.netloc}"


def validate_release(
    settings: AppSettings,
    runtime: RuntimeSettings,
    manifest: ReleaseManifest,
) -> list[str]:
    errors: list[str] = []

    try:
        api_origin = _origin(manifest.api_origin, "API origin")
    except ValueError as exc:
        errors.append(str(exc))
        api_origin = manifest.api_origin.rstrip("/")
    try:
        frontend_origin = _origin(manifest.frontend_origin, "Frontend origin")
    except ValueError as exc:
        errors.append(str(exc))
        frontend_origin = manifest.frontend_origin.rstrip("/")

    expected_webhook = (
        f"{api_origin}/v1/webhooks/payments/lemonsqueezy"
    )
    if manifest.payment_webhook_url != expected_webhook:
        errors.append(
            "Payment webhook URL must be "
            f"{expected_webhook}"
        )

    if settings.environment != "production":
        errors.append("SAVESTREAM_ENVIRONMENT must be production")
    if runtime.environment != "production":
        errors.append("Runtime environment must be production")
    if runtime.log_format != "json":
        errors.append("SAVESTREAM_LOG_FORMAT must be json in production")

    if settings.frontend_base_url != frontend_origin:
        errors.append(
            "SAVESTREAM_FRONTEND_BASE_URL must match the release frontend origin"
        )
    if frontend_origin not in settings.cors_allow_origins:
        errors.append(
            "SAVESTREAM_CORS_ALLOW_ORIGINS must include the release frontend origin"
        )
    if any(origin == "*" for origin in settings.cors_allow_origins):
        errors.append("Wildcard CORS is not allowed")

    if not settings.force_https:
        errors.append("SAVESTREAM_FORCE_HTTPS must be enabled")
    if not settings.security_headers_enabled:
        errors.append("SAVESTREAM_SECURITY_HEADERS_ENABLED must be enabled")
    if not settings.trusted_proxy_cidrs:
        errors.append("SAVESTREAM_TRUSTED_PROXY_CIDRS must be configured")

    storage = urlparse(settings.minio_endpoint)
    storage_secure = settings.minio_secure or storage.scheme == "https"
    if not storage_secure:
        errors.append("Production S3/MinIO transport must use TLS")
    if settings.minio_access_key == "savestream":
        errors.append("Production storage access key must not use the local default")
    if settings.minio_secret_key == "savestream-local-only":
        errors.append("Production storage secret must not use the local default")
    if not settings.minio_bucket:
        errors.append("Production storage bucket must be configured")

    if settings.recording_source_backend != "tiktok":
        errors.append(
            "SAVESTREAM_RECORDING_SOURCE_BACKEND must be tiktok in production"
        )

    if settings.payment_provider == "disabled":
        if not manifest.allow_disabled_payments:
            errors.append(
                "SAVESTREAM_PAYMENT_PROVIDER=disabled requires --allow-disabled-payments"
            )
    else:
        if settings.payment_provider != "lemonsqueezy":
            errors.append(
                "Production release manifest expects SAVESTREAM_PAYMENT_PROVIDER=lemonsqueezy"
            )
        if (
            settings.payment_provider_base_url.rstrip("/")
            != "https://api.lemonsqueezy.com/v1"
        ):
            errors.append(
                "Production Lemon Squeezy API URL must be https://api.lemonsqueezy.com/v1"
            )
        if not settings.lemon_squeezy_store_id:
            errors.append("Lemon Squeezy Live store ID must be configured")
        if not settings.lemon_squeezy_variant_id:
            errors.append("Lemon Squeezy Live variant ID must be configured")
        if settings.payment_provider_api_key == "payments-disabled":
            errors.append("Payment API key is still the payments-disabled placeholder")

    if settings.smtp_host in {"localhost", "mail-debug"}:
        errors.append("Production SMTP host must be external")
    if not settings.smtp_starttls:
        errors.append("Production SMTP must use STARTTLS")
    if not settings.ops_alert_email:
        errors.append("SAVESTREAM_OPS_ALERT_EMAIL must be configured")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate SaveStream production release configuration."
    )
    parser.add_argument(
        "--api-origin",
        default="https://api.savestream.online",
    )
    parser.add_argument(
        "--frontend-origin",
        default="https://savestream.online",
    )
    parser.add_argument(
        "--payment-webhook-url",
        default=(
            "https://api.savestream.online"
            "/v1/webhooks/payments/lemonsqueezy"
        ),
    )
    parser.add_argument(
        "--allow-disabled-payments",
        action="store_true",
        help="Accept SAVESTREAM_PAYMENT_PROVIDER=disabled (launch before live payments).",
    )
    args = parser.parse_args()

    settings = AppSettings.from_env()
    runtime = RuntimeSettings.from_env()
    manifest = ReleaseManifest(
        api_origin=args.api_origin.rstrip("/"),
        frontend_origin=args.frontend_origin.rstrip("/"),
        payment_webhook_url=args.payment_webhook_url,
        allow_disabled_payments=args.allow_disabled_payments,
    )
    errors = validate_release(settings, runtime, manifest)
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1

    print("release readiness checks passed")
    print(f"frontend origin: {manifest.frontend_origin}")
    print(f"api origin: {manifest.api_origin}")
    if settings.payment_provider == "disabled":
        print("payments: disabled (checkout fails closed; keep VITE_BILLING_CHECKOUT_ENABLED=false)")
    else:
        print(f"payment webhook: {manifest.payment_webhook_url}")
    print("oauth: disabled (no production OAuth backend is implemented)")
    print("secrets: validated without printing values")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
