from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from fastapi.testclient import TestClient

from app.api.dependencies import get_current_principal
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording, RecordingEvent
from app.infrastructure.db.session import Database
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_recording_sse_resumes_from_last_event_id_and_polling_remains_available(
    tmp_path,
) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase5-realtime.db'}"
    settings = replace(
        identity_settings(database_url),
        sse_poll_seconds=0.01,
    )

    async def seed() -> tuple[AuthPrincipal, str, str, str, str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="realtime@example.com",
                    normalized_email="realtime@example.com",
                    role="user",
                    email_verified_at=__import__(
                        "app.application.recordings.service",
                        fromlist=["utcnow"],
                    ).utcnow(),
                )
                session.add(user)
                await session.flush()
                recording = Recording(
                    user_id=user.id,
                    source_type="room_id",
                    source_value="room-realtime",
                    status="completed",
                    active_dedupe_key=None,
                    room_session_key="realtime-" + uuid.uuid4().hex,
                    duration_seconds=3,
                    bytes_recorded=300,
                    estimated_max_cost=0,
                    actual_cost=0,
                )
                session.add(recording)
                await session.flush()
                events = []
                for sequence, event_type, bytes_recorded in [
                    (1, "recording.started", 0),
                    (2, "recording.progress", 200),
                    (3, "recording.completed", 300),
                ]:
                    event = RecordingEvent(
                        recording_id=recording.id,
                        sequence=sequence,
                        event_type=event_type,
                        data={
                            "status": "completed",
                            "duration_seconds": sequence,
                            "bytes_recorded": bytes_recorded,
                        },
                    )
                    session.add(event)
                    events.append(event)
                await session.commit()
                for event in events:
                    await session.refresh(event)
                return (
                    AuthPrincipal(
                        user_id=user.id,
                        session_id=uuid.uuid4(),
                        role="user",
                        scopes=scopes_for_role("user"),
                    ),
                    str(recording.id),
                    str(events[0].id),
                    str(events[1].id),
                    str(events[2].id),
                )
        finally:
            await database.close()

    principal, recording_id, first_id, second_id, third_id = asyncio.run(seed())

    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: principal

    with TestClient(app, base_url="https://testserver") as client:
        poll = client.get(f"/v1/recordings/{recording_id}")
        assert poll.status_code == 200
        assert poll.json()["status"] == "completed"

        with client.stream(
            "GET",
            f"/v1/recordings/{recording_id}/events",
            headers={"Last-Event-ID": second_id},
        ) as response:
            assert response.status_code == 200
            body = "".join(response.iter_text())

    assert f"id: {third_id}" in body
    assert f"id: {first_id}" not in body
    assert f"id: {second_id}" not in body
    assert "recording.completed" in body
