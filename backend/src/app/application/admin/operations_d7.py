from __future__ import annotations

import asyncio
import base64
from collections.abc import Sequence
import json
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.identity.service import utcnow
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import (
    AdminBroadcast,
    AdminEmailLog,
    AdminEmailTemplate,
    AdminStorageRun,
)
from app.infrastructure.db.models import NotificationPreference, User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.email import templates
from app.infrastructure.email.smtp import SMTPEmailSender
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    raw = json.dumps(
        {"created_at": _aware(created_at).isoformat(), "id": str(row_id)},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode())
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError("VALIDATION_ERROR", "Invalid pagination cursor", status_code=400) from exc


class AdminOperationsService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings
        self.outbox = OutboxWriter()

    async def storage_summary(self) -> dict[str, object]:
        total = int(
            await self.session.scalar(
                select(func.coalesce(func.sum(RecordingArtifact.size_bytes), 0)).where(
                    RecordingArtifact.deleted_at.is_(None)
                )
            )
            or 0
        )
        user_rows = (
            await self.session.execute(
                select(
                    Recording.user_id,
                    User.email,
                    func.coalesce(func.sum(RecordingArtifact.size_bytes), 0).label("bytes"),
                )
                .join(Recording, Recording.id == RecordingArtifact.recording_id)
                .join(User, User.id == Recording.user_id)
                .where(RecordingArtifact.deleted_at.is_(None))
                .group_by(Recording.user_id, User.email)
                .order_by(func.sum(RecordingArtifact.size_bytes).desc())
                .limit(100)
            )
        ).all()
        since = utcnow() - timedelta(days=30)
        day_rows = (
            await self.session.execute(
                select(
                    func.date(RecordingArtifact.created_at).label("day"),
                    func.coalesce(func.sum(RecordingArtifact.size_bytes), 0).label("bytes"),
                )
                .where(
                    RecordingArtifact.deleted_at.is_(None),
                    RecordingArtifact.created_at >= since,
                )
                .group_by(func.date(RecordingArtifact.created_at))
                .order_by(func.date(RecordingArtifact.created_at))
            )
        ).all()
        cleanup = await self.session.scalar(
            select(AdminStorageRun)
            .where(AdminStorageRun.kind == "recording_cleanup")
            .order_by(AdminStorageRun.created_at.desc(), AdminStorageRun.id.desc())
            .limit(1)
        )
        return {
            "total_bytes": total,
            "by_user": [
                {"user_id": str(row.user_id), "email": row.email, "bytes": int(row.bytes or 0)}
                for row in user_rows
            ],
            "daily_trend": [
                {"day": str(row.day), "bytes": int(row.bytes or 0)} for row in day_rows
            ],
            "latest_cleanup": (
                {
                    "run_id": str(cleanup.id),
                    "created_at": cleanup.created_at,
                    "deleted_count": cleanup.deleted_count,
                    "scanned_count": cleanup.scanned_count,
                }
                if cleanup is not None
                else None
            ),
        }

    async def create_orphan_scan(self, *, actor_user_id: uuid.UUID, limit: int) -> AdminStorageRun:
        run = AdminStorageRun(
            kind="orphan_scan",
            status="queued",
            actor_user_id=actor_user_id,
            details={"limit": limit, "orphan_keys": [], "truncated": False},
        )
        self.session.add(run)
        await self.session.flush()
        await self.outbox.enqueue(
            self.session,
            topic="admin.storage.orphan_scan",
            aggregate_type="admin_storage_run",
            aggregate_id=str(run.id),
            payload={"run_id": str(run.id)},
        )
        await self.session.commit()
        await self.session.refresh(run)
        return run

    async def get_storage_run(self, run_id: str) -> AdminStorageRun:
        try:
            parsed = uuid.UUID(run_id)
        except ValueError as exc:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Storage run not found", status_code=404) from exc
        run = await self.session.get(AdminStorageRun, parsed)
        if run is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Storage run not found", status_code=404)
        return run

    async def create_orphan_delete(
        self,
        *,
        actor_user_id: uuid.UUID,
        source_run_id: str,
    ) -> AdminStorageRun:
        source = await self.get_storage_run(source_run_id)
        if source.kind != "orphan_scan" or source.status != "completed":
            raise ApplicationError(
                "VALIDATION_ERROR",
                "A completed orphan scan is required before deletion",
                status_code=409,
            )
        keys = list(source.details.get("orphan_keys", []))
        run = AdminStorageRun(
            kind="orphan_delete",
            status="queued",
            actor_user_id=actor_user_id,
            orphan_count=len(keys),
            details={"source_run_id": str(source.id), "orphan_keys": keys},
        )
        self.session.add(run)
        await self.session.flush()
        await self.outbox.enqueue(
            self.session,
            topic="admin.storage.orphan_delete",
            aggregate_type="admin_storage_run",
            aggregate_id=str(run.id),
            payload={"run_id": str(run.id)},
        )
        await self.session.commit()
        await self.session.refresh(run)
        return run

    async def list_email_logs(
        self,
        *,
        limit: int,
        cursor: str | None,
        recipient: str | None,
        kind: str | None,
        status: str | None,
        sort_order: str = "desc",
    ) -> tuple[list[AdminEmailLog], str | None, bool]:
        statement = select(AdminEmailLog)
        if recipient:
            statement = statement.where(AdminEmailLog.recipient_email.ilike(f"%{recipient.strip()}%"))
        if kind:
            statement = statement.where(AdminEmailLog.kind == kind)
        if status:
            statement = statement.where(AdminEmailLog.status == status)
        ascending = sort_order == "asc"
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            if ascending:
                statement = statement.where(
                    or_(
                        AdminEmailLog.created_at > created_at,
                        and_(AdminEmailLog.created_at == created_at, AdminEmailLog.id > row_id),
                    )
                )
            else:
                statement = statement.where(
                    or_(
                        AdminEmailLog.created_at < created_at,
                        and_(AdminEmailLog.created_at == created_at, AdminEmailLog.id < row_id),
                    )
                )
        order = (
            (AdminEmailLog.created_at.asc(), AdminEmailLog.id.asc())
            if ascending
            else (AdminEmailLog.created_at.desc(), AdminEmailLog.id.desc())
        )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(*order).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None
        return items, next_cursor, has_more

    async def get_email_log(self, log_id: str) -> AdminEmailLog:
        try:
            parsed = uuid.UUID(log_id)
        except ValueError as exc:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Email log not found", status_code=404) from exc
        log = await self.session.get(AdminEmailLog, parsed)
        if log is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Email log not found", status_code=404)
        return log

    async def email_templates(self) -> list[dict[str, object]]:
        result: list[dict[str, object]] = []
        for key, default in templates.EMAIL_TEMPLATE_DEFAULTS.items():
            override = await self.session.get(AdminEmailTemplate, key)
            result.append(
                {
                    "key": key,
                    "subject": override.subject if override is not None else default[0],
                    "body": override.body if override is not None else default[1],
                    "overridden": override is not None,
                    "updated_at": override.updated_at if override is not None else None,
                }
            )
        return result

    async def update_email_template(
        self,
        *,
        key: str,
        subject: str,
        body: str,
        actor_user_id: uuid.UUID,
    ) -> AdminEmailTemplate:
        if key not in templates.EMAIL_TEMPLATE_DEFAULTS:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Email template not found", status_code=404)
        row = await self.session.get(AdminEmailTemplate, key)
        if row is None:
            row = AdminEmailTemplate(key=key, subject=subject.strip(), body=body.strip())
            self.session.add(row)
        else:
            row.subject = subject.strip()
            row.body = body.strip()
        row.updated_by_user_id = actor_user_id
        row.updated_at = utcnow()
        await self.session.flush()
        return row

    async def reset_email_template(self, key: str) -> None:
        if key not in templates.EMAIL_TEMPLATE_DEFAULTS:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Email template not found", status_code=404)
        row = await self.session.get(AdminEmailTemplate, key)
        if row is not None:
            await self.session.delete(row)
            await self.session.flush()

    async def preview_email_template(self, key: str) -> templates.RenderedEmail:
        data = {item["key"]: item for item in await self.email_templates()}
        current = data.get(key)
        if current is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Email template not found", status_code=404)
        link = f"{self.settings.frontend_base_url}/example"
        if key == "verify_email":
            return templates.verify_email(
                link=link,
                expires_in_seconds=self.settings.one_time_token_ttl_seconds,
                site_url=self.settings.frontend_base_url,
                subject_override=str(current["subject"]),
                intro_override=str(current["body"]),
            )
        return templates.password_reset(
            link=link,
            expires_in_seconds=self.settings.one_time_token_ttl_seconds,
            site_url=self.settings.frontend_base_url,
            subject_override=str(current["subject"]),
            intro_override=str(current["body"]),
        )

    async def send_template_test(self, *, key: str, actor_user_id: uuid.UUID) -> AdminEmailLog:
        actor = await self.session.get(User, actor_user_id)
        if actor is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Admin account not found", status_code=404)
        email = await self.preview_email_template(key)
        log = AdminEmailLog(
            user_id=actor.id,
            recipient_email=actor.email,
            kind=f"template_test:{key}",
            subject=email.subject,
            status="sending",
            dedupe_key=f"template-test:{uuid.uuid4()}",
            attempts=1,
        )
        self.session.add(log)
        await self.session.commit()
        try:
            await asyncio.to_thread(
                SMTPEmailSender(self.settings).send,
                to=actor.email,
                subject=email.subject,
                text=email.text,
                html=email.html,
            )
        except Exception as exc:
            log.status = "failed"
            log.error = (str(exc) or type(exc).__name__)[:4000]
            await self.session.commit()
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Test email could not be sent",
                status_code=503,
            ) from exc
        log.status = "sent"
        log.sent_at = utcnow()
        await self.session.commit()
        await self.session.refresh(log)
        return log

    async def resend_email(self, log_id: str) -> AdminEmailLog:
        log = await self.get_email_log(log_id)
        if log.kind in {"verify_email", "password_reset"} and log.user_id is not None:
            from app.application.admin.service import AdminService

            await AdminService(self.session, self.settings).issue_identity_token(
                str(log.user_id),
                log.kind,
            )
            log.attempts += 1
            await self.session.flush()
            return log
        if log.kind.startswith("broadcast_"):
            parts = log.dedupe_key.split(":")
            if len(parts) < 4:
                raise ApplicationError("VALIDATION_ERROR", "Email cannot be resent", status_code=409)
            try:
                broadcast_id = uuid.UUID(parts[1])
            except ValueError as exc:
                raise ApplicationError("VALIDATION_ERROR", "Email cannot be resent", status_code=409) from exc
            broadcast = await self.session.get(AdminBroadcast, broadcast_id)
            if broadcast is None:
                raise ApplicationError("VALIDATION_ERROR", "Broadcast no longer exists", status_code=409)
            email = templates.message_email(
                subject=broadcast.title,
                body=broadcast.body,
                site_url=self.settings.frontend_base_url,
            )
            log.status = "sending"
            log.error = None
            log.attempts += 1
            await self.session.commit()
            try:
                await asyncio.to_thread(
                    SMTPEmailSender(self.settings).send,
                    to=log.recipient_email,
                    subject=email.subject,
                    text=email.text,
                    html=email.html,
                )
            except Exception as exc:
                log.status = "failed"
                log.error = (str(exc) or type(exc).__name__)[:4000]
                await self.session.commit()
                raise ApplicationError("SERVICE_UNAVAILABLE", "Email could not be resent", status_code=503) from exc
            log.status = "sent"
            log.sent_at = utcnow()
            await self.session.flush()
            return log
        raise ApplicationError("VALIDATION_ERROR", "Email cannot be resent", status_code=409)

    async def audience_count(self, kind: str) -> int:
        if kind == "system":
            statement = select(func.count()).select_from(User).where(User.is_active.is_(True))
        elif kind == "marketing":
            statement = (
                select(func.count())
                .select_from(User)
                .join(NotificationPreference, NotificationPreference.user_id == User.id)
                .where(User.is_active.is_(True), NotificationPreference.marketing.is_(True))
            )
        else:
            raise ApplicationError("VALIDATION_ERROR", "Invalid broadcast type", status_code=400)
        return int(await self.session.scalar(statement) or 0)

    async def create_broadcast(
        self,
        *,
        actor_user_id: uuid.UUID,
        kind: str,
        title: str,
        body: str,
        channels: Sequence[str],
        reason: str,
    ) -> AdminBroadcast:
        broadcast = AdminBroadcast(
            actor_user_id=actor_user_id,
            kind=kind,
            title=title.strip(),
            body=body.strip(),
            channels=list(channels),
            status="queued",
            audience_count=await self.audience_count(kind),
            reason=reason.strip(),
        )
        self.session.add(broadcast)
        await self.session.flush()
        await self.outbox.enqueue(
            self.session,
            topic="admin.broadcast",
            aggregate_type="admin_broadcast",
            aggregate_id=str(broadcast.id),
            payload={"broadcast_id": str(broadcast.id)},
        )
        await self.session.commit()
        await self.session.refresh(broadcast)
        return broadcast

    async def get_broadcast(self, broadcast_id: str) -> AdminBroadcast:
        try:
            parsed = uuid.UUID(broadcast_id)
        except ValueError as exc:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Broadcast not found", status_code=404) from exc
        row = await self.session.get(AdminBroadcast, parsed)
        if row is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Broadcast not found", status_code=404)
        return row

    async def list_broadcasts(
        self,
        *,
        limit: int,
        cursor: str | None,
        kind: str | None,
        status: str | None,
        query: str | None = None,
        sort_order: str = "desc",
    ) -> tuple[list[AdminBroadcast], str | None, bool]:
        statement = select(AdminBroadcast)
        if query:
            term = f"%{query.strip()}%"
            statement = statement.where(
                or_(AdminBroadcast.title.ilike(term), AdminBroadcast.body.ilike(term))
            )
        if kind:
            statement = statement.where(AdminBroadcast.kind == kind)
        if status:
            statement = statement.where(AdminBroadcast.status == status)
        ascending = sort_order == "asc"
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            if ascending:
                statement = statement.where(
                    or_(
                        AdminBroadcast.created_at > created_at,
                        and_(AdminBroadcast.created_at == created_at, AdminBroadcast.id > row_id),
                    )
                )
            else:
                statement = statement.where(
                    or_(
                        AdminBroadcast.created_at < created_at,
                        and_(AdminBroadcast.created_at == created_at, AdminBroadcast.id < row_id),
                    )
                )
        order = (
            (AdminBroadcast.created_at.asc(), AdminBroadcast.id.asc())
            if ascending
            else (AdminBroadcast.created_at.desc(), AdminBroadcast.id.desc())
        )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(*order).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None
        return items, next_cursor, has_more
