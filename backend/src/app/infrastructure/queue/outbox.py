from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from celery import Celery
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.models import OutboxEvent
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings

logger = logging.getLogger("savestream.outbox")


class OutboxWriter:
    async def enqueue(
        self,
        session: AsyncSession,
        *,
        topic: str,
        payload: dict,
        aggregate_type: str | None = None,
        aggregate_id: str | None = None,
        headers: dict | None = None,
    ) -> OutboxEvent:
        event = OutboxEvent(
            topic=topic,
            payload=payload,
            aggregate_type=aggregate_type,
            aggregate_id=aggregate_id,
            headers=headers or {},
        )
        session.add(event)
        await session.flush()
        return event


class OutboxDispatcher:
    def __init__(self, database: Database, celery: Celery, batch_size: int = 50) -> None:
        self.database = database
        self.celery = celery
        self.batch_size = batch_size

    async def run_once(self) -> int:
        now = datetime.now(timezone.utc)
        async with self.database.session() as session:
            async with session.begin():
                statement = (
                    select(OutboxEvent)
                    .where(
                        OutboxEvent.published_at.is_(None),
                        OutboxEvent.available_at <= now,
                    )
                    .order_by(OutboxEvent.occurred_at)
                    .limit(self.batch_size)
                    .with_for_update(skip_locked=True)
                )
                events = list((await session.scalars(statement)).all())
                for event in events:
                    self.celery.send_task(
                        "savestream.outbox.event",
                        kwargs={
                            "event_id": str(event.id),
                            "topic": event.topic,
                            "payload": event.payload,
                        },
                    )
                    event.attempts += 1
                    event.published_at = now
                return len(events)


async def dispatch_forever(settings: AppSettings | None = None) -> None:
    cfg = settings or get_app_settings()
    from .celery_app import create_celery_app

    database = Database(cfg.database_url)
    dispatcher = OutboxDispatcher(database, create_celery_app(cfg))
    try:
        while True:
            try:
                count = await dispatcher.run_once()
                if count == 0:
                    await asyncio.sleep(cfg.outbox_poll_seconds)
            except Exception:
                logger.exception("Outbox dispatch iteration failed")
                await asyncio.sleep(cfg.outbox_poll_seconds)
    finally:
        await database.close()


def main() -> None:
    asyncio.run(dispatch_forever())


if __name__ == "__main__":
    main()
