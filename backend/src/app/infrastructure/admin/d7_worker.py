from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import func, select

from app.application.identity.service import utcnow
from app.application.notifications.push import PushMessage, PushTokenInvalid
from app.infrastructure.db.admin_models import (
    AdminBroadcast,
    AdminBroadcastDelivery,
    AdminEmailLog,
    AdminStorageRun,
)
from app.infrastructure.db.models import (
    DeviceRegistration,
    NotificationPreference,
    User,
    UserNotification,
)
from app.infrastructure.db.recording_models import RecordingArtifact
from app.infrastructure.db.session import Database
from app.infrastructure.email import templates
from app.infrastructure.email.smtp import SMTPEmailSender
from app.infrastructure.push.factory import selected_push_sender
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings, get_app_settings

_RATE_LIMIT_SECONDS = 0.05


async def _orphan_scan(run_id: uuid.UUID, settings: AppSettings) -> None:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            run = await session.get(AdminStorageRun, run_id)
            if run is None or run.kind != "orphan_scan":
                return
            run.status = "running"
            run.started_at = utcnow()
            await session.commit()
            try:
                limit = max(1, min(int(run.details.get("limit", 1000)), 5000))
                keys = await asyncio.to_thread(
                    MinioStorageClient(settings).list_keys,
                    limit=limit,
                )
                known = set(
                    (
                        await session.scalars(select(RecordingArtifact.storage_key))
                    ).all()
                )
                orphan_keys = [key for key in keys if key not in known]
                run.scanned_count = len(keys)
                run.orphan_count = len(orphan_keys)
                run.details = {
                    "limit": limit,
                    "orphan_keys": orphan_keys,
                    "truncated": len(keys) >= limit,
                }
                run.status = "completed"
                run.completed_at = utcnow()
                await session.commit()
            except Exception as exc:
                run.status = "failed"
                run.error = (str(exc) or type(exc).__name__)[:4000]
                run.completed_at = utcnow()
                await session.commit()
                raise
    finally:
        await database.close()


async def _orphan_delete(run_id: uuid.UUID, settings: AppSettings) -> None:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            run = await session.get(AdminStorageRun, run_id)
            if run is None or run.kind != "orphan_delete":
                return
            run.status = "running"
            run.started_at = utcnow()
            await session.commit()
            storage = MinioStorageClient(settings)
            keys = [str(item) for item in run.details.get("orphan_keys", [])][:5000]
            deleted = 0
            errors: list[str] = []
            for key in keys:
                try:
                    await asyncio.to_thread(storage.remove, key)
                    deleted += 1
                except Exception as exc:
                    errors.append(f"{key}: {(str(exc) or type(exc).__name__)[:300]}")
            run.scanned_count = len(keys)
            run.deleted_count = deleted
            run.error = "\n".join(errors[:20]) or None
            run.status = "completed"
            run.completed_at = utcnow()
            await session.commit()
    finally:
        await database.close()


async def _audience(session, kind: str) -> list[User]:
    if kind == "marketing":
        statement = (
            select(User)
            .join(NotificationPreference, NotificationPreference.user_id == User.id)
            .where(User.is_active.is_(True), NotificationPreference.marketing.is_(True))
            .order_by(User.id)
        )
    else:
        statement = select(User).where(User.is_active.is_(True)).order_by(User.id)
    return list((await session.scalars(statement)).all())


async def _delivery(session, broadcast_id: uuid.UUID, user_id: uuid.UUID, channel: str) -> AdminBroadcastDelivery:
    row = await session.scalar(
        select(AdminBroadcastDelivery).where(
            AdminBroadcastDelivery.broadcast_id == broadcast_id,
            AdminBroadcastDelivery.user_id == user_id,
            AdminBroadcastDelivery.channel == channel,
        )
    )
    if row is None:
        row = AdminBroadcastDelivery(
            broadcast_id=broadcast_id,
            user_id=user_id,
            channel=channel,
            status="queued",
        )
        session.add(row)
        await session.flush()
    return row


async def _broadcast(broadcast_id: uuid.UUID, settings: AppSettings) -> None:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            broadcast = await session.get(AdminBroadcast, broadcast_id)
            if broadcast is None:
                return
            broadcast.status = "running"
            broadcast.started_at = broadcast.started_at or utcnow()
            users = await _audience(session, broadcast.kind)
            broadcast.audience_count = len(users)
            await session.commit()
            push_sender = selected_push_sender(settings)
            smtp = SMTPEmailSender(settings)

            for user in users:
                for channel in list(broadcast.channels):
                    delivery = await _delivery(session, broadcast.id, user.id, channel)
                    if delivery.status == "delivered":
                        continue
                    try:
                        if channel == "in_app":
                            dedupe_key = f"broadcast:{broadcast.id}:{broadcast.kind}"
                            notification_id = uuid.uuid5(
                                uuid.NAMESPACE_URL,
                                f"savestream:{user.id}:{dedupe_key}",
                            )
                            notification = await session.get(UserNotification, notification_id)
                            if notification is None:
                                session.add(
                                    UserNotification(
                                        id=notification_id,
                                        user_id=user.id,
                                        kind=f"admin_{broadcast.kind}",
                                        title=broadcast.title,
                                        body=broadcast.body,
                                        resource_type="broadcast",
                                        resource_id=str(broadcast.id),
                                        dedupe_key=dedupe_key,
                                    )
                                )
                        elif channel == "push":
                            devices = list(
                                (
                                    await session.scalars(
                                        select(DeviceRegistration).where(
                                            DeviceRegistration.user_id == user.id,
                                            DeviceRegistration.push_token.is_not(None),
                                        )
                                    )
                                ).all()
                            )
                            sent = 0
                            for device in devices:
                                if not device.push_token:
                                    continue
                                try:
                                    await push_sender.send(
                                        device.push_token,
                                        PushMessage(
                                            title=broadcast.title,
                                            body=broadcast.body,
                                            data={
                                                "type": f"admin_{broadcast.kind}",
                                                "broadcast_id": str(broadcast.id),
                                            },
                                        ),
                                    )
                                    sent += 1
                                except PushTokenInvalid:
                                    device.push_token = None
                            if sent == 0:
                                delivery.status = "skipped"
                                delivery.error = "No registered push device"
                                continue
                        elif channel == "email":
                            email = templates.message_email(
                                subject=broadcast.title,
                                body=broadcast.body,
                                site_url=settings.frontend_base_url,
                            )
                            dedupe = f"broadcast:{broadcast.id}:{user.id}:email"
                            log = await session.scalar(
                                select(AdminEmailLog).where(AdminEmailLog.dedupe_key == dedupe)
                            )
                            if log is None:
                                log = AdminEmailLog(
                                    user_id=user.id,
                                    recipient_email=user.email,
                                    kind=f"broadcast_{broadcast.kind}",
                                    subject=email.subject,
                                    status="sending",
                                    dedupe_key=dedupe,
                                    attempts=1,
                                )
                                session.add(log)
                                await session.flush()
                            elif log.status == "sent":
                                delivery.status = "delivered"
                                delivery.delivered_at = log.sent_at or utcnow()
                                continue
                            else:
                                log.status = "sending"
                                log.error = None
                                log.attempts += 1
                            try:
                                await asyncio.to_thread(
                                    smtp.send,
                                    to=user.email,
                                    subject=email.subject,
                                    text=email.text,
                                    html=email.html,
                                )
                            except Exception as exc:
                                log.status = "failed"
                                log.error = (str(exc) or type(exc).__name__)[:4000]
                                raise
                            log.status = "sent"
                            log.sent_at = utcnow()
                        else:
                            delivery.status = "failed"
                            delivery.error = "Unsupported broadcast channel"
                            continue
                        delivery.status = "delivered"
                        delivery.error = None
                        delivery.delivered_at = utcnow()
                    except Exception as exc:
                        delivery.status = "failed"
                        delivery.error = (str(exc) or type(exc).__name__)[:4000]
                    await session.commit()
                await asyncio.sleep(_RATE_LIMIT_SECONDS)

            deliveries = list(
                (
                    await session.scalars(
                        select(AdminBroadcastDelivery).where(
                            AdminBroadcastDelivery.broadcast_id == broadcast.id
                        )
                    )
                ).all()
            )
            broadcast.delivered_in_app = sum(
                item.status == "delivered" and item.channel == "in_app" for item in deliveries
            )
            broadcast.delivered_push = sum(
                item.status == "delivered" and item.channel == "push" for item in deliveries
            )
            broadcast.delivered_email = sum(
                item.status == "delivered" and item.channel == "email" for item in deliveries
            )
            broadcast.failed_count = sum(item.status == "failed" for item in deliveries)
            broadcast.status = "completed"
            broadcast.completed_at = utcnow()
            await session.commit()
    finally:
        await database.close()


def run_orphan_scan(run_id: str) -> None:
    asyncio.run(_orphan_scan(uuid.UUID(run_id), get_app_settings()))


def run_orphan_delete(run_id: str) -> None:
    asyncio.run(_orphan_delete(uuid.UUID(run_id), get_app_settings()))


def run_broadcast(broadcast_id: str) -> None:
    asyncio.run(_broadcast(uuid.UUID(broadcast_id), get_app_settings()))
