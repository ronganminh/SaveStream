from __future__ import annotations

import asyncio
import base64
import uuid
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.application.partners import CONSENT_DISPLAY, CONSENT_OWNS_ACCOUNT
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.admin_models import PartnerApplication
from app.infrastructure.db.models import AuditLog, User
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32

APPLICATION = {
    "name": "Maya Chen",
    "email": "Maya@Example.com",
    "tiktok_handle": "@MayaFit",
    "other_channel_url": "https://youtube.com/@mayafit",
    "niche": "Fitness",
    "story": "I run two-hour LIVE workouts and cut the best parts into clips every week.",
    "consent_owns_account": True,
    "consent_display": True,
}


class FakeStorage:
    def __init__(self) -> None:
        self.objects: dict[str, tuple[bytes, str]] = {}

    def upload_bytes(self, data: bytes, key: str, *, content_type: str) -> None:
        self.objects[key] = (data, content_type)

    def get_bytes(self, key: str, *, max_bytes: int) -> tuple[bytes, str] | None:
        return self.objects.get(key)


def _app(tmp_path, **overrides):
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'partners.db'}"
    settings = replace(identity_settings(database_url), **overrides)
    create_schema(database_url)
    return create_app(settings), database_url


def _start(client: TestClient, app) -> FakeStorage:
    storage = FakeStorage()
    app.state.rate_limiter = InMemoryRateLimiter()
    app.state.minio = storage
    return storage


def _rows(database_url: str, model):
    async def run():
        database = Database(database_url)
        try:
            async with database.session() as session:
                return list((await session.scalars(select(model))).all())
        finally:
            await database.close()

    return asyncio.run(run())


def _principal(database_url: str, role: str, *, mfa: bool = True) -> AuthPrincipal:
    async def run() -> AuthPrincipal:
        database = Database(database_url)
        try:
            async with database.session() as session:
                user = User(
                    email=f"{role}-partners@example.com",
                    normalized_email=f"{role}-partners@example.com",
                    role=role,
                )
                session.add(user)
                await session.commit()
                return AuthPrincipal(
                    user.id, uuid.uuid4(), role, scopes_for_role(role), admin_mfa_verified=mfa
                )
        finally:
            await database.close()

    return asyncio.run(run())


def test_application_stores_consent_record_and_photo(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    photo = "data:image/png;base64," + base64.b64encode(PNG).decode()
    with TestClient(app, base_url="https://testserver") as client:
        storage = _start(client, app)
        response = client.post(
            "/v1/public/partner-applications",
            json={**APPLICATION, "photo": photo},
            headers={"user-agent": "pytest-browser"},
        )

    assert response.status_code == 201, response.text
    [row] = _rows(database_url, PartnerApplication)
    assert response.json()["reference"] == "PA-" + row.id.hex[:8].upper()
    assert row.status == "pending"
    assert row.email == "maya@example.com"
    assert row.tiktok_handle == "mayafit"
    assert row.consent_texts == [CONSENT_OWNS_ACCOUNT, CONSENT_DISPLAY]
    assert row.terms_version and row.privacy_version
    assert row.consent_ip
    assert row.consent_user_agent == "pytest-browser"
    assert row.photo_key == f"partner-photos/{row.id.hex}.png"
    assert storage.objects[row.photo_key] == (PNG, "image/png")


def test_application_requires_both_confirmations_and_valid_photo(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    with TestClient(app, base_url="https://testserver") as client:
        _start(client, app)
        no_consent = client.post(
            "/v1/public/partner-applications", json={**APPLICATION, "consent_display": False}
        )
        bad_photo = client.post(
            "/v1/public/partner-applications",
            json={**APPLICATION, "photo": "data:image/gif;base64,R0lGODlhAQABAAAAACw="},
        )
        bad_niche = client.post(
            "/v1/public/partner-applications", json={**APPLICATION, "niche": "Crypto"}
        )

    for response in (no_consent, bad_photo, bad_niche):
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert _rows(database_url, PartnerApplication) == []


def test_honeypot_and_rate_limit(tmp_path) -> None:
    app, database_url = _app(tmp_path, public_report_rate_limit=2)
    with TestClient(app, base_url="https://testserver") as client:
        _start(client, app)
        trap = client.post(
            "/v1/public/partner-applications", json={**APPLICATION, "website": "x.example"}
        )
        ok = client.post("/v1/public/partner-applications", json=APPLICATION)
        limited = client.post("/v1/public/partner-applications", json=APPLICATION)

    assert trap.status_code == 201
    assert trap.json()["reference"] == "PA-00000000"
    assert ok.status_code == 201
    assert limited.status_code == 429
    assert len(_rows(database_url, PartnerApplication)) == 1


def test_admin_review_flow_is_audited(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    support = _principal(database_url, "support")
    photo = "data:image/png;base64," + base64.b64encode(PNG).decode()
    reason = "Story checked against the channel."
    with TestClient(app, base_url="https://testserver") as client:
        _start(client, app)
        client.post("/v1/public/partner-applications", json={**APPLICATION, "photo": photo})
        app.dependency_overrides[get_current_principal] = lambda: support

        listing = client.get("/v1/admin/partners", params={"status": "pending"}).json()
        [item] = listing["items"]
        assert listing["counts"] == {"pending": 1}
        assert item["has_photo"] is True
        assert item["consent_texts"] == [CONSENT_OWNS_ACCOUNT, CONSENT_DISPLAY]
        assert client.get("/v1/admin/partners", params={"query": "@maya"}).json()["items"]

        image = client.get(f"/v1/admin/partners/{item['id']}/photo")
        assert image.status_code == 200
        assert image.content == PNG
        assert image.headers["cache-control"] == "private, no-store"

        path = f"/v1/admin/partners/{item['id']}/actions"
        early = client.post(path, json={"action": "publish", "reason": reason})
        assert early.status_code == 409
        statuses = [
            client.post(path, json={"action": action, "reason": reason}).json()["status"]
            for action in ("approve", "publish", "unpublish")
        ]
        assert statuses == ["approved", "published", "withdrawn"]
        again = client.post(path, json={"action": "publish", "reason": reason})
        assert again.status_code == 409

    [row] = _rows(database_url, PartnerApplication)
    assert row.consent_withdrawn_at is not None
    assert row.published_at is None
    actions = sorted(log.action for log in _rows(database_url, AuditLog))
    assert actions == ["partner.approve", "partner.publish", "partner.unpublish"]


def test_admin_endpoints_need_admin_scope_and_mfa(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    customer = _principal(database_url, "user")
    finance = _principal(database_url, "finance")
    no_mfa = replace(_principal(database_url, "support"), admin_mfa_verified=False)
    with TestClient(app, base_url="https://testserver") as client:
        _start(client, app)
        codes = []
        for principal in (customer, finance, no_mfa):
            app.dependency_overrides[get_current_principal] = lambda p=principal: p
            codes.append(client.get("/v1/admin/partners").json()["error"]["code"])

    assert codes == ["FORBIDDEN", "FORBIDDEN", "ADMIN_MFA_REQUIRED"]
