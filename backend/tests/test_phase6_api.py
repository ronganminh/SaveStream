from __future__ import annotations

import asyncio
import uuid

from fastapi.testclient import TestClient

from app.api.dependencies import get_current_principal
from app.application.recordings.service import RecordingService, utcnow
from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.main import create_app
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings


def test_credit_and_pricing_read_endpoints(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase6-api.db'}"
    settings = identity_settings(database_url)

    async def seed() -> AuthPrincipal:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="credits-api@example.com",
                    normalized_email="credits-api@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id, 100)
                principal = AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
                await RecordingService(session, settings).create(
                    principal,
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="api-room"),
                        max_duration_seconds=60,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                return principal
        finally:
            await database.close()

    principal = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: principal

    with TestClient(app, base_url="https://testserver") as client:
        pricing = client.get("/v1/pricing")
        assert pricing.status_code == 200
        assert pricing.json()["version"] == "test-duration-v1"
        assert pricing.json()["credit_unit"] == "credit"

        balance = client.get("/v1/credits/balance")
        assert balance.status_code == 200
        assert balance.json() == {"posted": 100, "reserved": 2, "available": 98}

        reservations = client.get("/v1/credits/reservations")
        assert reservations.status_code == 200
        assert len(reservations.json()["items"]) == 1
        assert reservations.json()["items"][0]["reserved"] == 2

        transactions = client.get("/v1/credits/transactions")
        assert transactions.status_code == 200
        assert transactions.json()["items"][0]["type"] == "adjustment"
