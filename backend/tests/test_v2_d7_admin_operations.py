from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from datetime import timedelta

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.application.identity.service import utcnow
from app.application.privacy.service import PrivacyService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.admin_models import AdminEmailLog
from app.infrastructure.db.models import AuditLog, Base, NotificationPreference, User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.session import Database
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_d7_admin_operations_rbac_audience_storage_and_retention(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd7-admin.db'}"
    settings = replace(identity_settings(database_url), signup_credits=0)

    async def seed() -> dict[str, uuid.UUID]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                owner = User(email="owner@example.com", normalized_email="owner@example.com", role="owner", email_verified_at=utcnow())
                support = User(email="support@example.com", normalized_email="support@example.com", role="support", email_verified_at=utcnow())
                finance = User(email="finance@example.com", normalized_email="finance@example.com", role="finance", email_verified_at=utcnow())
                legacy = User(email="legacy-admin@example.com", normalized_email="legacy-admin@example.com", role="admin", email_verified_at=utcnow())
                opted = User(email="opted@example.com", normalized_email="opted@example.com", role="user", email_verified_at=utcnow())
                plain = User(email="plain@example.com", normalized_email="plain@example.com", role="user", email_verified_at=utcnow())
                session.add_all([owner, support, finance, legacy, opted, plain])
                await session.flush()
                session.add(NotificationPreference(user_id=opted.id, marketing=True))
                rec = Recording(
                    user_id=plain.id,
                    source_type="username",
                    source_value="creator",
                    status="completed",
                    quality="best",
                    container="mp4",
                    duration_seconds=60,
                    bytes_recorded=2048,
                    estimated_max_cost=1,
                    actual_cost=1,
                )
                session.add(rec)
                await session.flush()
                session.add(
                    RecordingArtifact(
                        recording_id=rec.id,
                        kind="video",
                        container="mp4",
                        storage_key=f"users/{plain.id}/recordings/{rec.id}/video.mp4",
                        size_bytes=2048,
                        checksum_sha256="a" * 64,
                    )
                )
                session.add(
                    AdminEmailLog(
                        user_id=plain.id,
                        recipient_email=plain.email,
                        kind="password_reset",
                        subject="Reset",
                        status="sent",
                        dedupe_key="d7-current",
                        attempts=1,
                        sent_at=utcnow(),
                    )
                )
                session.add(
                    AdminEmailLog(
                        user_id=plain.id,
                        recipient_email=plain.email,
                        kind="password_reset",
                        subject="Old",
                        status="sent",
                        dedupe_key="d7-old",
                        attempts=1,
                        sent_at=utcnow() - timedelta(days=91),
                        created_at=utcnow() - timedelta(days=91),
                    )
                )
                await session.commit()
                return {
                    "owner": owner.id,
                    "support": support.id,
                    "finance": finance.id,
                    "admin": legacy.id,
                }
        finally:
            await database.close()

    ids = asyncio.run(seed())
    app = create_app(settings)

    def principal(role: str) -> AuthPrincipal:
        return AuthPrincipal(
            user_id=ids[role],
            session_id=uuid.uuid4(),
            role=role,
            scopes=scopes_for_role(role),
            admin_mfa_verified=True,
        )

    with TestClient(app, base_url="https://testserver") as client:
        app.dependency_overrides[get_current_principal] = lambda: principal("support")
        storage = client.get("/v1/admin/storage/summary")
        assert storage.status_code == 200
        assert storage.json()["total_bytes"] == 2048
        logs = client.get("/v1/admin/email/logs")
        assert logs.status_code == 200
        assert any(item["recipient_email"] == "plain@example.com" for item in logs.json()["items"])

        app.dependency_overrides[get_current_principal] = lambda: principal("finance")
        assert client.get("/v1/admin/email/logs").status_code == 403

        app.dependency_overrides[get_current_principal] = lambda: principal("owner")
        assert client.get("/v1/admin/email/templates").status_code == 200
        marketing = client.post(
            "/v1/admin/broadcasts/preview",
            json={"kind": "marketing", "channels": ["in_app"]},
        )
        assert marketing.status_code == 200
        assert marketing.json()["audience_count"] == 1
        missing_step_up = client.post(
            "/v1/admin/broadcasts",
            json={
                "kind": "system",
                "channels": ["in_app"],
                "title": "Maintenance",
                "body": "Scheduled maintenance.",
                "reason": "Maintenance notice",
            },
        )
        assert missing_step_up.status_code == 403

        app.dependency_overrides[get_current_principal] = lambda: principal("admin")
        queued = client.post(
            "/v1/admin/broadcasts",
            json={
                "kind": "system",
                "channels": ["in_app"],
                "title": "Maintenance",
                "body": "Scheduled maintenance.",
                "reason": "Maintenance notice",
            },
        )
        assert queued.status_code == 200
        assert queued.json()["status"] == "queued"

    async def verify() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                audit = list(
                    (
                        await session.scalars(
                            select(AuditLog).where(AuditLog.action == "admin.broadcast.queued")
                        )
                    ).all()
                )
                assert audit
                await PrivacyService(session).prune_ephemeral()
                await session.commit()
                logs = list((await session.scalars(select(AdminEmailLog))).all())
                assert {item.dedupe_key for item in logs} == {"d7-current"}
        finally:
            await database.close()

    asyncio.run(verify())
