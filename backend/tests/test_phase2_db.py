from __future__ import annotations

import asyncio

from sqlalchemy import select

from app.infrastructure.db.models import Base, OutboxEvent
from app.infrastructure.db.session import Database
from app.infrastructure.queue.outbox import OutboxWriter


def test_phase2_base_tables_are_registered() -> None:
    assert {
        "users",
        "idempotency_keys",
        "outbox_events",
        "audit_logs",
    }.issubset(set(Base.metadata.tables))
    assert Base.metadata.tables["users"].c.normalized_email.unique is True


def test_sqlalchemy_models_and_outbox_work_on_async_database(tmp_path) -> None:
    async def run() -> None:
        database = Database(f"sqlite+aiosqlite:///{tmp_path / 'phase2.db'}")
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                async with session.begin():
                    event = await OutboxWriter().enqueue(
                        session,
                        topic="phase2.test",
                        payload={"ok": True},
                    )
                    event_id = event.id

            async with database.session() as session:
                saved = await session.scalar(
                    select(OutboxEvent).where(OutboxEvent.id == event_id)
                )
                assert saved is not None
                assert saved.topic == "phase2.test"
                assert saved.payload == {"ok": True}
        finally:
            await database.close()

    asyncio.run(run())
