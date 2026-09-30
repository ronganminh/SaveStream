from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.application.recordings.service import utcnow
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import AuditLog, Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.main import create_app
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings


def test_phase8_admin_retry_creates_new_recording_and_audit(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase8-retry.db'}"
    settings = replace(
        identity_settings(database_url),
        metrics_token="phase8-metrics-secret",
    )

    async def seed() -> tuple[AuthPrincipal, str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                admin = User(
                    email="retry-admin@example.com",
                    normalized_email="retry-admin@example.com",
                    role="admin",
                    email_verified_at=utcnow(),
                )
                owner = User(
                    email="retry-owner@example.com",
                    normalized_email="retry-owner@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add_all([admin, owner])
                await session.commit()
                await session.refresh(admin)
                await session.refresh(owner)
                await configure_test_pricing(session)
                await grant_test_credits(session, owner.id, 100)
                failed = Recording(
                    user_id=owner.id,
                    source_type="username",
                    source_value="retry-creator",
                    status="failed",
                    active_dedupe_key=None,
                    quality="best",
                    container="mp4",
                    max_duration_seconds=60,
                    duration_seconds=0,
                    bytes_recorded=0,
                    estimated_max_cost=2,
                    actual_cost=0,
                    error_code="STREAM_UNAVAILABLE",
                    error_message="temporary",
                    error_retryable=True,
                    ended_at=utcnow(),
                )
                session.add(failed)
                await session.commit()
                await session.refresh(failed)
                return (
                    AuthPrincipal(
                        admin.id,
                        uuid.uuid4(),
                        "admin",
                        scopes_for_role("admin"),
                    ),
                    str(failed.id),
                )
        finally:
            await database.close()

    admin_principal, failed_id = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: admin_principal

    with TestClient(app, base_url="https://testserver") as client:
        response = client.post(
            f"/v1/admin/recordings/{failed_id}/retry",
            headers={"Idempotency-Key": str(uuid.uuid4())},
        )
        assert response.status_code == 200
        payload = response.json()
        assert payload["original_recording_id"] == failed_id
        assert payload["recording"]["id"] != failed_id
        assert payload["recording"]["status"] == "queued"
        retry_id = payload["recording"]["id"]

    async def verify() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                original = await session.get(Recording, uuid.UUID(failed_id))
                retry = await session.get(Recording, uuid.UUID(retry_id))
                assert original is not None and original.status == "failed"
                assert retry is not None and retry.status == "queued"
                audit = await session.scalar(
                    select(AuditLog).where(
                        AuditLog.action == "admin.recording.retried"
                    )
                )
                assert audit is not None
                assert audit.resource_id == failed_id
                assert audit.details["retry_recording_id"] == retry_id
        finally:
            await database.close()

    asyncio.run(verify())
