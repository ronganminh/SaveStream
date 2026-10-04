from __future__ import annotations

import httpx

from scripts.release_smoke import _check_app_status, _check_entitlement


def _client(handler):
    return httpx.Client(transport=httpx.MockTransport(handler))


def test_app_status_smoke_accepts_v2_shape() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/app/status"
        return httpx.Response(
            200,
            json={
                "min_supported_version": {"android": "2.0.0", "ios": "2.0.0"},
                "maintenance": {"active": False, "eta": None},
            },
        )

    with _client(handler) as client:
        assert _check_app_status(client, "https://api.example") is None


def test_entitlement_smoke_checks_auth_boundary_without_token() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/me/entitlement"
        assert "Authorization" not in request.headers
        return httpx.Response(401, json={"error": {"code": "UNAUTHORIZED"}})

    with _client(handler) as client:
        assert _check_entitlement(client, "https://api.example", None) is None


def test_entitlement_smoke_validates_authenticated_v2_shape() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer release-token"
        return httpx.Response(
            200,
            json={
                "plan": "pro",
                "limits": {
                    "max_watches": 20,
                    "max_concurrent_cloud_recordings": 3,
                    "cloud_retention_days": 30,
                },
                "local": {"enabled": True, "unlimited": True},
            },
        )

    with _client(handler) as client:
        assert (
            _check_entitlement(
                client,
                "https://api.example",
                "release-token",
            )
            is None
        )
