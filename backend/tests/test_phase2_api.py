from __future__ import annotations

from fastapi.testclient import TestClient

from app.api.errors import AppError
from app.main import create_app
from app.settings import AppSettings


def settings() -> AppSettings:
    return AppSettings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        redis_url="redis://localhost:6379/15",
        celery_broker_url="memory://",
        celery_result_backend="cache+memory://",
        minio_endpoint="http://localhost:9000",
        minio_access_key="test",
        minio_secret_key="test",
        cors_allow_origins=("http://localhost:5173",),
    )


def test_liveness_and_request_id() -> None:
    app = create_app(settings())
    with TestClient(app) as client:
        response = client.get("/health/live", headers={"X-Request-ID": "req_test_123"})
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["X-Request-ID"] == "req_test_123"


def test_invalid_request_id_is_replaced() -> None:
    app = create_app(settings())
    with TestClient(app) as client:
        response = client.get("/health/live", headers={"X-Request-ID": "contains spaces"})
    assert response.status_code == 200
    assert response.headers["X-Request-ID"] != "contains spaces"


def test_error_envelope_uses_machine_readable_code_and_request_id() -> None:
    app = create_app(settings())

    @app.get("/_test/error", include_in_schema=False)
    async def raise_error() -> None:
        raise AppError(
            "SERVICE_UNAVAILABLE",
            "dependency unavailable",
            status_code=503,
            retryable=True,
        )

    with TestClient(app) as client:
        response = client.get("/_test/error", headers={"X-Request-ID": "req_error"})

    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "SERVICE_UNAVAILABLE",
            "message": "dependency unavailable",
            "request_id": "req_error",
            "retryable": True,
            "details": {},
        }
    }


def test_cors_is_allowlisted() -> None:
    app = create_app(settings())
    with TestClient(app) as client:
        response = client.options(
            "/health/live",
            headers={
                "Origin": "http://localhost:5173",
                "Access-Control-Request-Method": "GET",
            },
        )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


def test_readiness_reports_each_dependency() -> None:
    class Healthy:
        async def ping(self) -> bool:
            return True

    class Unhealthy:
        async def ping(self) -> bool:
            return False

    app = create_app(settings())
    with TestClient(app) as client:
        app.state.database = Healthy()
        app.state.redis = Healthy()
        app.state.minio = Unhealthy()
        response = client.get("/health/ready")

    assert response.status_code == 503
    payload = response.json()
    assert payload["status"] == "error"
    assert payload["components"]["postgres"]["status"] == "ok"
    assert payload["components"]["redis"]["status"] == "ok"
    assert payload["components"]["minio"]["status"] == "error"
