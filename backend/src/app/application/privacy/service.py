from __future__ import annotations

import uuid
from datetime import timedelta
from typing import Any

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.recordings.retention import paid_customer_clause, retention_days
from app.application.recordings.service import utcnow
from app.infrastructure.db.billing_models import PaymentOrder, Refund
from app.infrastructure.db.credit_models import CreditLedgerEntry, CreditReservation
from app.infrastructure.db.models import (
    ApiKey,
    AuditLog,
    AuthSession,
    IdempotencyKey,
    NotificationPreference,
    OneTimeToken,
    PasswordCredential,
    User,
    UserNotification,
)
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


class PrivacyService:
    def __init__(
        self,
        session: AsyncSession,
        *,
        outbox: OutboxWriter | None = None,
    ) -> None:
        self.session = session
        self.outbox = outbox or OutboxWriter()

    async def export_user(self, user_id: uuid.UUID) -> dict[str, Any]:
        user = await self.session.get(User, user_id)
        if user is None:
            return {}

        watches = list(
            (
                await self.session.scalars(
                    select(Watch)
                    .where(Watch.user_id == user_id)
                    .order_by(Watch.created_at)
                )
            ).all()
        )
        recordings = list(
            (
                await self.session.scalars(
                    select(Recording)
                    .where(Recording.user_id == user_id)
                    .order_by(Recording.created_at)
                )
            ).all()
        )
        recording_ids = [item.id for item in recordings]
        artifacts = (
            list(
                (
                    await self.session.scalars(
                        select(RecordingArtifact)
                        .where(RecordingArtifact.recording_id.in_(recording_ids))
                        .order_by(RecordingArtifact.created_at)
                    )
                ).all()
            )
            if recording_ids
            else []
        )
        ledger = list(
            (
                await self.session.scalars(
                    select(CreditLedgerEntry)
                    .where(CreditLedgerEntry.user_id == user_id)
                    .order_by(CreditLedgerEntry.created_at)
                )
            ).all()
        )
        reservations = list(
            (
                await self.session.scalars(
                    select(CreditReservation)
                    .where(CreditReservation.user_id == user_id)
                    .order_by(CreditReservation.created_at)
                )
            ).all()
        )
        payments = list(
            (
                await self.session.scalars(
                    select(PaymentOrder)
                    .where(PaymentOrder.user_id == user_id)
                    .order_by(PaymentOrder.created_at)
                )
            ).all()
        )
        refunds = list(
            (
                await self.session.scalars(
                    select(Refund)
                    .where(Refund.user_id == user_id)
                    .order_by(Refund.created_at)
                )
            ).all()
        )
        audit = list(
            (
                await self.session.scalars(
                    select(AuditLog)
                    .where(AuditLog.actor_user_id == user_id)
                    .order_by(AuditLog.created_at)
                )
            ).all()
        )
        notifications = list(
            (
                await self.session.scalars(
                    select(UserNotification)
                    .where(UserNotification.user_id == user_id)
                    .order_by(UserNotification.created_at)
                )
            ).all()
        )
        notification_preferences = await self.session.get(
            NotificationPreference,
            user_id,
        )
        return {
            "schema_version": 1,
            "generated_at": utcnow(),
            "profile": {
                "id": str(user.id),
                "email": user.email,
                "display_name": user.display_name,
                "locale": user.locale,
                "role": user.role,
                "created_at": user.created_at,
                "deletion_requested_at": user.deletion_requested_at,
                "deletion_completed_at": user.deletion_completed_at,
            },
            "watches": [
                {
                    "id": str(item.id),
                    "source_type": item.source_type,
                    "source_value": item.source_value,
                    "status": item.status,
                    "live_status": item.live_status,
                    "auto_record": item.auto_record,
                    "created_at": item.created_at,
                    "deleted_at": item.deleted_at,
                }
                for item in watches
            ],
            "recordings": [
                {
                    "id": str(item.id),
                    "source_type": item.source_type,
                    "source_value": item.source_value,
                    "status": item.status,
                    "duration_seconds": item.duration_seconds,
                    "bytes_recorded": item.bytes_recorded,
                    "estimated_max_cost": item.estimated_max_cost,
                    "actual_cost": item.actual_cost,
                    "created_at": item.created_at,
                    "started_at": item.started_at,
                    "ended_at": item.ended_at,
                    "deleted_at": item.deleted_at,
                }
                for item in recordings
            ],
            "artifacts": [
                {
                    "id": str(item.id),
                    "recording_id": str(item.recording_id),
                    "kind": item.kind,
                    "container": item.container,
                    "size_bytes": item.size_bytes,
                    "checksum_sha256": item.checksum_sha256,
                    "created_at": item.created_at,
                    "deleted_at": item.deleted_at,
                }
                for item in artifacts
            ],
            "credit_ledger": [
                {
                    "id": str(item.id),
                    "type": item.entry_type,
                    "amount": item.amount,
                    "balance_after": item.balance_after,
                    "reference_type": item.reference_type,
                    "reference_id": item.reference_id,
                    "created_at": item.created_at,
                }
                for item in ledger
            ],
            "credit_reservations": [
                {
                    "id": str(item.id),
                    "recording_id": str(item.recording_id),
                    "reserved": item.reserved,
                    "settled": item.settled,
                    "released": item.released,
                    "status": item.status,
                    "created_at": item.created_at,
                }
                for item in reservations
            ],
            "payments": [
                {
                    "id": str(item.id),
                    "status": item.status,
                    "credits": item.credits,
                    "amount_minor": item.amount_minor,
                    "currency": item.currency,
                    "provider": item.provider,
                    "created_at": item.created_at,
                    "paid_at": item.paid_at,
                }
                for item in payments
            ],
            "refunds": [
                {
                    "id": str(item.id),
                    "payment_order_id": str(item.payment_order_id),
                    "status": item.status,
                    "credits": item.credits,
                    "amount_minor": item.amount_minor,
                    "created_at": item.created_at,
                }
                for item in refunds
            ],
            "audit": [
                {
                    "id": str(item.id),
                    "action": item.action,
                    "resource_type": item.resource_type,
                    "resource_id": item.resource_id,
                    "request_id": item.request_id,
                    "created_at": item.created_at,
                }
                for item in audit
            ],
            "notifications": [
                {
                    "id": str(item.id),
                    "type": item.kind,
                    "title": item.title,
                    "body": item.body,
                    "resource_type": item.resource_type,
                    "resource_id": item.resource_id,
                    "read_at": item.read_at,
                    "created_at": item.created_at,
                }
                for item in notifications
            ],
            "notification_preferences": (
                {
                    "recording_started": notification_preferences.recording_started,
                    "recording_ready": notification_preferences.recording_ready,
                    "recording_failed": notification_preferences.recording_failed,
                    "updated_at": notification_preferences.updated_at,
                }
                if notification_preferences is not None
                else None
            ),
        }

    async def apply_recording_retention(self, settings: AppSettings) -> int:
        paid_days = retention_days(settings, paid=True)
        free_days = retention_days(settings, paid=False)
        rows: list[Recording] = []
        for days, paid in ((paid_days, True), (free_days, False)):
            if days <= 0:
                continue
            paid_users = paid_customer_clause()
            owner = Recording.user_id.in_(paid_users) if paid else Recording.user_id.not_in(paid_users)
            rows.extend(
                (
                    await self.session.scalars(
                        select(Recording).where(
                            Recording.deleted_at.is_(None),
                            Recording.status.in_(["completed", "failed", "stopped"]),
                            Recording.created_at < utcnow() - timedelta(days=days),
                            owner,
                        )
                    )
                ).all()
            )
        now = utcnow()
        for recording in rows:
            recording.deleted_at = now
            recording.cleanup_requested_at = now
            recording.active_dedupe_key = None
            recording.room_session_key = None
            await self.outbox.enqueue(
                self.session,
                topic="recording.cleanup",
                aggregate_type="recording",
                aggregate_id=str(recording.id),
                payload={"recording_id": str(recording.id), "reason": "retention"},
            )
        return len(rows)

    async def anonymize_due_accounts(self, settings: AppSettings) -> int:
        cutoff = utcnow() - timedelta(days=settings.account_deletion_grace_days)
        users = list(
            (
                await self.session.scalars(
                    select(User).where(
                        User.deletion_requested_at.is_not(None),
                        User.deletion_requested_at <= cutoff,
                        User.deletion_completed_at.is_(None),
                    )
                )
            ).all()
        )
        for user in users:
            now = utcnow()
            recordings = list(
                (
                    await self.session.scalars(
                        select(Recording).where(Recording.user_id == user.id)
                    )
                ).all()
            )
            for recording in recordings:
                if recording.deleted_at is None:
                    recording.deleted_at = now
                    recording.cleanup_requested_at = now
                    await self.outbox.enqueue(
                        self.session,
                        topic="recording.cleanup",
                        aggregate_type="recording",
                        aggregate_id=str(recording.id),
                        payload={"recording_id": str(recording.id), "reason": "account_deletion"},
                    )
                recording.source_value = "deleted"
                recording.resolved_username = None
                recording.room_id = None
                recording.room_session_key = None
                recording.active_dedupe_key = None

            watches = list(
                (
                    await self.session.scalars(
                        select(Watch).where(Watch.user_id == user.id)
                    )
                ).all()
            )
            for watch in watches:
                watch.source_value = "deleted"
                watch.resolved_username = None
                watch.resolved_room_id = None
                watch.active_dedupe_key = None
                watch.status = "disabled"
                watch.next_check_at = None
                watch.deleted_at = watch.deleted_at or now

            await self.session.execute(
                delete(PasswordCredential).where(PasswordCredential.user_id == user.id)
            )
            await self.session.execute(
                delete(AuthSession).where(AuthSession.user_id == user.id)
            )
            await self.session.execute(
                delete(OneTimeToken).where(OneTimeToken.user_id == user.id)
            )
            await self.session.execute(delete(ApiKey).where(ApiKey.user_id == user.id))
            await self.session.execute(
                delete(UserNotification).where(UserNotification.user_id == user.id)
            )
            await self.session.execute(
                delete(NotificationPreference).where(
                    NotificationPreference.user_id == user.id
                )
            )
            await self.session.execute(
                update(AuditLog)
                .where(AuditLog.actor_user_id == user.id)
                .values(ip_address=None, user_agent=None)
            )
            user.email = f"deleted+{user.id.hex}@deleted.savestream.invalid"
            user.normalized_email = user.email
            user.display_name = None
            user.email_verified_at = None
            user.is_active = False
            user.deletion_completed_at = now
            self.session.add(
                AuditLog(
                    actor_user_id=user.id,
                    action="privacy.account_deleted",
                    resource_type="user",
                    resource_id=str(user.id),
                    details={"financial_records_preserved": True},
                )
            )
        return len(users)

    async def anonymize_user(self, user_id: uuid.UUID) -> bool:
        user = await self.session.get(User, user_id)
        if user is None or user.deletion_completed_at is not None:
            return False
        now = utcnow()
        recordings = list(
            (
                await self.session.scalars(
                    select(Recording).where(Recording.user_id == user.id)
                )
            ).all()
        )
        for recording in recordings:
            if recording.deleted_at is None:
                recording.deleted_at = now
                recording.cleanup_requested_at = now
                await self.outbox.enqueue(
                    self.session,
                    topic="recording.cleanup",
                    aggregate_type="recording",
                    aggregate_id=str(recording.id),
                    payload={"recording_id": str(recording.id), "reason": "account_deletion"},
                )
            recording.source_value = "deleted"
            recording.resolved_username = None
            recording.room_id = None
            recording.room_session_key = None
            recording.active_dedupe_key = None

        watches = list(
            (
                await self.session.scalars(
                    select(Watch).where(Watch.user_id == user.id)
                )
            ).all()
        )
        for watch in watches:
            watch.source_value = "deleted"
            watch.resolved_username = None
            watch.resolved_room_id = None
            watch.active_dedupe_key = None
            watch.status = "disabled"
            watch.next_check_at = None
            watch.deleted_at = watch.deleted_at or now

        await self.session.execute(
            delete(PasswordCredential).where(PasswordCredential.user_id == user.id)
        )
        await self.session.execute(delete(AuthSession).where(AuthSession.user_id == user.id))
        await self.session.execute(delete(OneTimeToken).where(OneTimeToken.user_id == user.id))
        await self.session.execute(delete(ApiKey).where(ApiKey.user_id == user.id))
        await self.session.execute(
            delete(UserNotification).where(UserNotification.user_id == user.id)
        )
        await self.session.execute(
            delete(NotificationPreference).where(NotificationPreference.user_id == user.id)
        )
        await self.session.execute(
            update(AuditLog)
            .where(AuditLog.actor_user_id == user.id)
            .values(ip_address=None, user_agent=None)
        )
        user.email = f"deleted+{user.id.hex}@deleted.savestream.invalid"
        user.normalized_email = user.email
        user.display_name = None
        user.email_verified_at = None
        user.is_active = False
        user.deletion_requested_at = user.deletion_requested_at or now
        user.deletion_completed_at = now
        self.session.add(
            AuditLog(
                actor_user_id=user.id,
                action="privacy.account_deleted",
                resource_type="user",
                resource_id=str(user.id),
                details={"financial_records_preserved": True},
            )
        )
        await self.session.flush()
        return True

    async def prune_ephemeral(self) -> int:
        now = utcnow()
        keys = await self.session.execute(
            delete(IdempotencyKey)
            .where(IdempotencyKey.expires_at < now)
            .returning(IdempotencyKey.id)
        )
        tokens = await self.session.execute(
            delete(OneTimeToken)
            .where(OneTimeToken.expires_at < now)
            .returning(OneTimeToken.id)
        )
        return len(list(keys.scalars())) + len(list(tokens.scalars()))
