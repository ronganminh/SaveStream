from __future__ import annotations

import asyncio
import uuid

from app.application.billing.credits import BillingCreditService
from app.application.entitlements.service import EntitlementService
from app.application.quotas.service import QuotaService
from app.application.recordings.cloud_slots import CloudSlotQueueService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.settings import get_app_settings


async def _user(session, label: str) -> User:
    email = f"c9-{label}-{uuid.uuid4().hex}@example.test"
    user = User(
        email=email,
        normalized_email=email.casefold(),
        role="user",
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def _paid_user(session) -> User:
    user = await _user(session, "paid")
    package = CreditPackage(
        code=f"c9-{uuid.uuid4().hex}",
        name="C9 E2E package",
        credits=100,
        amount_minor=999,
        currency="USD",
        active=True,
    )
    session.add(package)
    await session.flush()
    order = PaymentOrder(
        user_id=user.id,
        package_id=package.id,
        status="paid",
        credits=100,
        amount_minor=999,
        currency="USD",
    )
    session.add(order)
    await session.commit()
    await session.refresh(order)
    await BillingCreditService(session).grant_purchase(
        user_id=user.id,
        payment_order_id=order.id,
        credits=100,
    )
    await session.commit()
    return user


async def run() -> None:
    settings = get_app_settings()
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            free = await _user(session, "free")
            free_entitlement = await EntitlementService(session, settings).get(free.id)
            assert free_entitlement.max_watches == 3
            assert free_entitlement.max_concurrent_cloud_recordings == 0

            for index in range(3):
                session.add(
                    Watch(
                        user_id=free.id,
                        source_type="room_id",
                        source_value=f"c9-free-{index}",
                        active_dedupe_key=uuid.uuid4().hex,
                        status="active",
                        live_status="offline",
                        auto_record=False,
                    )
                )
            await session.commit()
            try:
                await QuotaService(session, settings).check_watch_create(free.id)
            except ApplicationError as exc:
                assert exc.code == "WATCH_LIMIT_REACHED"
                assert exc.details == {"limit": 3, "plan": "free"}
            else:
                raise AssertionError("Free watch limit was not enforced")

            pro = await _paid_user(session)
            pro_entitlement = await EntitlementService(session, settings).get(pro.id)
            assert pro_entitlement.max_watches == 20
            assert pro_entitlement.max_concurrent_cloud_recordings == 3

            for index in range(3):
                session.add(
                    Recording(
                        user_id=pro.id,
                        source_type="room_id",
                        source_value=f"c9-active-{index}",
                        room_id=f"c9-active-{index}",
                        status="recording",
                        active_dedupe_key=f"c9-active-{uuid.uuid4().hex}",
                        room_session_key=f"c9-session-{uuid.uuid4().hex}",
                        max_duration_seconds=60,
                        quality="best",
                        container="mp4",
                    )
                )
            first_watch = Watch(
                user_id=pro.id,
                source_type="room_id",
                source_value="c9-wait-1",
                active_dedupe_key=uuid.uuid4().hex,
                status="active",
                live_status="live",
                auto_record=True,
            )
            second_watch = Watch(
                user_id=pro.id,
                source_type="room_id",
                source_value="c9-wait-2",
                active_dedupe_key=uuid.uuid4().hex,
                status="active",
                live_status="live",
                auto_record=True,
            )
            session.add_all([first_watch, second_watch])
            await session.commit()
            await session.refresh(first_watch)
            await session.refresh(second_watch)

            queue = CloudSlotQueueService(session, settings)
            first = await queue.queue_for_watch(first_watch, "c9-wait-1")
            second = await queue.queue_for_watch(second_watch, "c9-wait-2")
            assert first.status == "waiting_for_cloud_slot"
            assert second.status == "waiting_for_cloud_slot"
            assert await queue.queue_position(first) == 1
            assert await queue.queue_position(second) == 2
    finally:
        await database.close()


def main() -> None:
    asyncio.run(run())


if __name__ == "__main__":
    main()
