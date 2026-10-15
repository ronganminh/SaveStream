"""Account suspension / termination: admin action with reason and audit,
monitoring paused and sessions revoked, sign-in shows the status only after a
correct password, nothing is deleted, reinstating resumes paused channels."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import AuditLog, OutboxEvent, User
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings
from tests.test_phase11_notifications import _register_verify_login

PASSWORD = "correct horse battery staple"


def _db(url):
    return Database(url)


def _run(url, fn):
    async def go():
        database = _db(url)
        try:
            async with database.session() as session:
                return await fn(session)
        finally:
            await database.close()

    return asyncio.run(go())


def test_suspend_reinstate_terminate_flow(tmp_path) -> None:
    url = f"sqlite+aiosqlite:///{tmp_path / 'status.db'}"
    settings = identity_settings(url)
    create_schema(url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        token = _register_verify_login(client, settings, "creator@example.com")
        headers = {"Authorization": f"Bearer {token}"}
        mine = client.post(
            "/v1/watches",
            headers=headers,
            json={"source": {"type": "username", "value": "my.channel"}, "auto_record": False},
        )
        assert mine.status_code == 201, mine.text
        paused_by_user = client.post(
            "/v1/watches",
            headers=headers,
            json={"source": {"type": "username", "value": "paused.channel"}, "auto_record": False},
        ).json()["id"]
        client.patch(f"/v1/watches/{paused_by_user}", headers=headers, json={"status": "paused"})

        async def ids(session):
            user = await session.scalar(select(User).where(User.email == "creator@example.com"))
            admin = User(email="owner@example.com", normalized_email="owner@example.com", role="owner")
            session.add(admin)
            await session.commit()
            return user.id, admin.id

        user_id, admin_id = _run(url, ids)
        # Legacy "admin" role skips the step-up token in tests; owner scopes.
        owner = AuthPrincipal(admin_id, uuid.uuid4(), "admin", scopes_for_role("owner"))
        app.dependency_overrides[get_current_principal] = lambda: owner
        path = f"/v1/admin/users/{user_id}/account-status"

        short = client.post(path, json={"status": "suspended", "reason": "short"})
        assert short.status_code == 400
        suspended = client.post(
            path,
            json={
                "status": "suspended",
                "reason": "Recording LIVEs without the channel owner's permission",
                "reference": "SR-1040",
            },
        )
        assert suspended.status_code == 200, suspended.text
        assert suspended.json()["account_status"] == "suspended"
        app.dependency_overrides.clear()

        # Old access token no longer works; wrong password stays generic.
        assert client.get("/v1/watches", headers=headers).status_code == 401
        wrong = client.post(
            "/v1/auth/login",
            json={"email": "creator@example.com", "password": "nope-nope-nope", "client_type": "web"},
        )
        assert wrong.json()["error"]["code"] == "AUTH_INVALID_CREDENTIALS"
        blocked = client.post(
            "/v1/auth/login",
            json={"email": "creator@example.com", "password": PASSWORD, "client_type": "web"},
        )
        assert blocked.status_code == 403
        error = blocked.json()["error"]
        assert error["code"] == "ACCOUNT_SUSPENDED"
        assert error["details"]["reference"] == "SR-1040"
        assert "permission" in error["details"]["reason"]

        async def watch_states(session):
            rows = (await session.scalars(select(Watch).where(Watch.user_id == user_id))).all()
            return {row.source_value: (row.status, row.last_error) for row in rows}

        assert _run(url, watch_states) == {
            "my.channel": ("paused", "account_suspended"),
            "paused.channel": ("paused", None),
        }

        app.dependency_overrides[get_current_principal] = lambda: owner
        reinstated = client.post(
            path, json={"status": "active", "reason": "Appeal accepted: owner showed proof."}
        )
        assert reinstated.json()["account_status"] == "active"
        app.dependency_overrides.clear()
        states = _run(url, watch_states)
        assert states["my.channel"][0] == "active" and states["paused.channel"][0] == "paused"
        relogin = client.post(
            "/v1/auth/login",
            json={"email": "creator@example.com", "password": PASSWORD, "client_type": "web"},
        )
        assert relogin.status_code == 200

        app.dependency_overrides[get_current_principal] = lambda: owner
        terminated = client.post(
            path, json={"status": "terminated", "reason": "Repeated copyright infringement."}
        )
        assert terminated.json()["account_status"] == "terminated"
        locked_in = client.post(
            path, json={"status": "active", "reason": "Trying to undo the closure."}
        )
        assert locked_in.status_code == 409
        app.dependency_overrides.clear()
        closed = client.post(
            "/v1/auth/login",
            json={"email": "creator@example.com", "password": PASSWORD, "client_type": "web"},
        )
        assert closed.json()["error"]["code"] == "ACCOUNT_TERMINATED"

    async def audit_and_mail(session):
        actions = [row.action for row in (await session.scalars(select(AuditLog))).all()]
        mails = [
            row.payload["kind"]
            for row in (
                await session.scalars(select(OutboxEvent).where(OutboxEvent.topic == "account.email"))
            ).all()
        ]
        watches = (await session.scalars(select(Watch).where(Watch.user_id == user_id))).all()
        return actions, mails, watches

    actions, mails, watches = _run(url, audit_and_mail)
    assert {"admin.user.suspended", "admin.user.reinstated", "admin.user.terminated"} <= set(actions)
    assert mails == ["account_suspended", "account_reinstated", "account_terminated"]
    assert len(watches) == 2 and all(watch.deleted_at is None for watch in watches)


def test_admins_cannot_be_suspended(tmp_path) -> None:
    url = f"sqlite+aiosqlite:///{tmp_path / 'status-admin.db'}"
    settings = replace(identity_settings(url))
    create_schema(url)
    app = create_app(settings)

    async def seed(session):
        target = User(email="support@example.com", normalized_email="support@example.com", role="support")
        actor = User(email="o@example.com", normalized_email="o@example.com", role="owner")
        session.add_all([target, actor])
        await session.commit()
        return target.id, actor.id

    target_id, actor_id = _run(url, seed)
    owner = AuthPrincipal(actor_id, uuid.uuid4(), "admin", scopes_for_role("owner"))
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        app.dependency_overrides[get_current_principal] = lambda: owner
        response = client.post(
            f"/v1/admin/users/{target_id}/account-status",
            json={"status": "suspended", "reason": "This should not be allowed."},
        )
    assert response.status_code == 403
