from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Generic, TypeVar

from sqlalchemy import and_, exists, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.credits.service import CreditBalance, CreditService
from app.application.entitlements.service import EntitlementService, EntitlementSnapshot
from app.application.identity.service import utcnow
from app.application.recordings.retention import PAID_ORDER_STATUSES
from app.application.recordings.service import RecordingService
from app.domain.billing.state import PaymentStatus
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.admin_models import AdminMfaCredential, AdminUserNote
from app.infrastructure.db.billing_models import PaymentOrder
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry, CreditReservation
from app.infrastructure.db.models import (
    AuditLog,
    AuthSession,
    OneTimeToken,
    User,
    UserNotification,
)
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings

T = TypeVar("T")


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    payload = json.dumps(
        {"created_at": _aware(created_at).isoformat(), "id": str(row_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


@dataclass(frozen=True, slots=True)
class AdminPage(Generic[T]):
    items: list[T]
    next_cursor: str | None
    has_more: bool


@dataclass(frozen=True, slots=True)
class AdminUserDetailData:
    user: User
    entitlement: EntitlementSnapshot
    balance: CreditBalance
    latest_purchase_provider: str | None
    watches: list[Watch]
    recordings: list[Recording]
    payments: list[PaymentOrder]
    ledger: list[CreditLedgerEntry]
    sessions: list[AuthSession]
    notifications: list[UserNotification]
    notes: list[AdminUserNote]
    audit: list[AuditLog]


class AdminService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def list_users(
        self,
        *,
        limit: int,
        cursor: str | None,
        role: str | None,
        is_active: bool | None,
        query: str | None = None,
        plan: str | None = None,
        account_status: str | None = None,
        email_verified: bool | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
        purchase_provider: str | None = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> AdminPage[User]:
        statement = select(User)
        if role is not None:
            if role not in {"user", "owner", "support", "finance", "admin"}:
                raise ApplicationError("VALIDATION_ERROR", "Invalid role", status_code=400)
            statement = statement.where(User.role == role)
        if is_active is not None:
            statement = statement.where(User.is_active.is_(is_active))
        if query:
            statement = statement.where(User.normalized_email.ilike(f"%{query.strip().lower()}%"))
        if account_status is not None:
            if account_status == "active":
                statement = statement.where(
                    User.is_active.is_(True),
                    User.deletion_requested_at.is_(None),
                )
            elif account_status == "locked":
                statement = statement.where(
                    User.is_active.is_(False),
                    User.deletion_requested_at.is_(None),
                    User.deletion_completed_at.is_(None),
                )
            elif account_status == "pending_deletion":
                statement = statement.where(
                    User.deletion_requested_at.is_not(None),
                    User.deletion_completed_at.is_(None),
                )
            elif account_status == "deleted":
                statement = statement.where(User.deletion_completed_at.is_not(None))
            else:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid account status", status_code=400
                )
        if email_verified is not None:
            statement = statement.where(
                User.email_verified_at.is_not(None)
                if email_verified
                else User.email_verified_at.is_(None)
            )
        if created_from is not None:
            statement = statement.where(User.created_at >= created_from)
        if created_to is not None:
            statement = statement.where(User.created_at <= created_to)

        paid_exists = exists().where(
            PaymentOrder.user_id == User.id,
            PaymentOrder.status.in_(PAID_ORDER_STATUSES),
        )
        posted_balance = (
            select(CreditAccount.posted_balance)
            .where(CreditAccount.user_id == User.id)
            .correlate(User)
            .scalar_subquery()
        )
        active_reserved = (
            select(
                func.coalesce(
                    func.sum(
                        CreditReservation.reserved
                        - CreditReservation.settled
                        - CreditReservation.released
                    ),
                    0,
                )
            )
            .where(
                CreditReservation.user_id == User.id,
                CreditReservation.status == "active",
            )
            .correlate(User)
            .scalar_subquery()
        )
        available = func.coalesce(posted_balance, 0) - func.coalesce(active_reserved, 0)
        if plan is not None:
            if plan == "pro":
                statement = statement.where(paid_exists, available > 0)
            elif plan == "free":
                statement = statement.where(or_(~paid_exists, available <= 0))
            else:
                raise ApplicationError("VALIDATION_ERROR", "Invalid plan", status_code=400)

        latest_provider = (
            select(PaymentOrder.provider)
            .where(
                PaymentOrder.user_id == User.id,
                PaymentOrder.status.in_(PAID_ORDER_STATUSES),
            )
            .order_by(PaymentOrder.created_at.desc(), PaymentOrder.id.desc())
            .limit(1)
            .correlate(User)
            .scalar_subquery()
        )
        if purchase_provider is not None:
            statement = statement.where(latest_provider == purchase_provider)

        if sort_by not in {"created_at", "email"}:
            raise ApplicationError("VALIDATION_ERROR", "Invalid sort field", status_code=400)
        if sort_order not in {"asc", "desc"}:
            raise ApplicationError("VALIDATION_ERROR", "Invalid sort order", status_code=400)

        cursor_payload: dict[str, str] | None = None
        if cursor:
            try:
                padded = cursor + "=" * (-len(cursor) % 4)
                cursor_payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
            except (ValueError, json.JSONDecodeError) as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
                ) from exc
            if cursor_payload.get("sort_by") != sort_by:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Pagination cursor does not match sort field", status_code=400
                )
            row_id = uuid.UUID(cursor_payload["id"])
            if sort_by == "email":
                email_value = cursor_payload["email"]
                if sort_order == "desc":
                    statement = statement.where(
                        or_(
                            User.normalized_email < email_value,
                            and_(
                                User.normalized_email == email_value,
                                User.id < row_id,
                            ),
                        )
                    )
                else:
                    statement = statement.where(
                        or_(
                            User.normalized_email > email_value,
                            and_(
                                User.normalized_email == email_value,
                                User.id > row_id,
                            ),
                        )
                    )
            else:
                created_value = datetime.fromisoformat(cursor_payload["created_at"])
                if sort_order == "desc":
                    statement = statement.where(
                        or_(
                            User.created_at < created_value,
                            and_(User.created_at == created_value, User.id < row_id),
                        )
                    )
                else:
                    statement = statement.where(
                        or_(
                            User.created_at > created_value,
                            and_(User.created_at == created_value, User.id > row_id),
                        )
                    )

        primary_sort = User.normalized_email if sort_by == "email" else User.created_at
        if sort_order == "desc":
            statement = statement.order_by(primary_sort.desc(), User.id.desc())
        else:
            statement = statement.order_by(primary_sort.asc(), User.id.asc())

        rows = list((await self.session.scalars(statement.limit(limit + 1))).all())
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = None
        if has_more and items:
            last = items[-1]
            payload = {
                "sort_by": sort_by,
                "id": str(last.id),
                "email": last.normalized_email,
                "created_at": _aware(last.created_at).isoformat(),
            }
            next_cursor = base64.urlsafe_b64encode(
                json.dumps(payload, separators=(",", ":")).encode("utf-8")
            ).decode("ascii").rstrip("=")
        return AdminPage(items, next_cursor, has_more)

    async def user_summary(
        self,
        user: User,
    ) -> tuple[EntitlementSnapshot, CreditBalance, str | None]:
        entitlement = await EntitlementService(self.session, self.settings).get(user.id)
        balance = await CreditService(self.session).balance(user.id)
        provider = await self.session.scalar(
            select(PaymentOrder.provider)
            .where(
                PaymentOrder.user_id == user.id,
                PaymentOrder.status.in_(PAID_ORDER_STATUSES),
            )
            .order_by(PaymentOrder.created_at.desc(), PaymentOrder.id.desc())
            .limit(1)
        )
        return entitlement, balance, provider

    async def get_user(self, user_id: str) -> User:
        try:
            parsed = uuid.UUID(user_id)
        except ValueError as exc:
            raise self._user_not_found() from exc
        user = await self.session.get(User, parsed)
        if user is None:
            raise self._user_not_found()
        return user

    async def update_user(
        self,
        *,
        actor_user_id: uuid.UUID,
        user_id: str,
        role: str | None,
        is_active: bool | None,
    ) -> User:
        user = await self.get_user(user_id)
        if user.id == actor_user_id and (role == "user" or is_active is False):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Admin cannot demote or deactivate the current session owner",
                status_code=409,
            )
        if role is not None:
            if role not in {"user", "owner", "support", "finance", "admin"}:
                raise ApplicationError("VALIDATION_ERROR", "Invalid role", status_code=400)
            user.role = role
        if is_active is not None:
            user.is_active = is_active
        await self.session.flush()
        return user


    async def list_admins(
        self,
        *,
        limit: int,
        cursor: str | None,
    ) -> AdminPage[User]:
        statement = select(User).where(
            User.role.in_(("owner", "support", "finance", "admin"))
        )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    User.created_at < created_at,
                    and_(User.created_at == created_at, User.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(User.created_at.desc(), User.id.desc()).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AdminPage(
            items,
            _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None,
            has_more,
        )

    async def set_admin_role(
        self,
        *,
        actor_user_id: uuid.UUID,
        user_id: str,
        role: str,
    ) -> tuple[User, str]:
        user = await self.get_user(user_id)
        previous_role = user.role
        if user.id == actor_user_id and role == "user":
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Owner cannot revoke the current session's own admin role",
                status_code=409,
            )
        if role not in {"user", "owner", "support", "finance"}:
            raise ApplicationError("VALIDATION_ERROR", "Invalid admin role", status_code=400)
        user.role = role
        # Changing privileges invalidates MFA verification on every existing session.
        await self.session.execute(
            update(AuthSession)
            .where(AuthSession.user_id == user.id)
            .values(admin_mfa_verified_at=None)
        )
        await self.session.flush()
        return user, previous_role

    async def reset_admin_mfa(self, user_id: str) -> User:
        user = await self.get_user(user_id)
        if user.role not in {"owner", "support", "finance", "admin"}:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "MFA can only be reset for an admin account",
                status_code=409,
            )
        row = await self.session.get(AdminMfaCredential, user.id)
        if row is not None:
            await self.session.delete(row)
        await self.session.execute(
            update(AuthSession)
            .where(AuthSession.user_id == user.id)
            .values(admin_mfa_verified_at=None)
        )
        await self.session.flush()
        return user

    async def list_recordings(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None,
        status: str | None,
    ) -> AdminPage[Recording]:
        statement = select(Recording).where(Recording.deleted_at.is_(None))
        if user_id is not None:
            statement = statement.where(Recording.user_id == user_id)
        if status is not None:
            try:
                RecordingStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid recording status", status_code=400
                ) from exc
            statement = statement.where(Recording.status == status)
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    Recording.created_at < created_at,
                    and_(Recording.created_at == created_at, Recording.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        Recording.created_at.desc(), Recording.id.desc()
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AdminPage(
            items,
            _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None,
            has_more,
        )

    async def get_recording(self, recording_id: str) -> Recording:
        try:
            parsed = uuid.UUID(recording_id)
        except ValueError as exc:
            raise self._recording_not_found() from exc
        recording = await self.session.scalar(
            select(Recording).where(
                Recording.id == parsed,
                Recording.deleted_at.is_(None),
            )
        )
        if recording is None:
            raise self._recording_not_found()
        return recording

    async def retry_recording(
        self,
        *,
        recording_id: str,
        idempotency_key: str,
    ) -> tuple[Recording, Recording]:
        original = await self.get_recording(recording_id)
        if RecordingStatus(original.status) is not RecordingStatus.FAILED:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Only failed recordings can be retried",
                status_code=409,
            )
        retry = await RecordingService(self.session, self.settings).create_for_user(
            original.user_id,
            CreateRecordingRequest.model_validate(
                {
                    "source": {
                        "type": original.source_type,
                        "value": original.source_value,
                    },
                    "max_duration_seconds": original.max_duration_seconds,
                    "quality": original.quality,
                    "container": original.container,
                }
            ),
            idempotency_key=idempotency_key,
        )
        return original, retry

    async def list_payments(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None,
        status: str | None,
    ) -> AdminPage[PaymentOrder]:
        statement = select(PaymentOrder)
        if user_id is not None:
            statement = statement.where(PaymentOrder.user_id == user_id)
        if status is not None:
            try:
                PaymentStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid payment status", status_code=400
                ) from exc
            statement = statement.where(PaymentOrder.status == status)
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    PaymentOrder.created_at < created_at,
                    and_(PaymentOrder.created_at == created_at, PaymentOrder.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        PaymentOrder.created_at.desc(), PaymentOrder.id.desc()
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AdminPage(
            items,
            _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None,
            has_more,
        )

    async def get_user_detail(self, user_id: str) -> AdminUserDetailData:
        user = await self.get_user(user_id)
        entitlement, balance, provider = await self.user_summary(user)
        watches = list(
            (
                await self.session.scalars(
                    select(Watch)
                    .where(Watch.user_id == user.id, Watch.deleted_at.is_(None))
                    .order_by(Watch.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        recordings = list(
            (
                await self.session.scalars(
                    select(Recording)
                    .where(Recording.user_id == user.id, Recording.deleted_at.is_(None))
                    .order_by(Recording.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        payments = list(
            (
                await self.session.scalars(
                    select(PaymentOrder)
                    .where(PaymentOrder.user_id == user.id)
                    .order_by(PaymentOrder.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        ledger = list(
            (
                await self.session.scalars(
                    select(CreditLedgerEntry)
                    .where(CreditLedgerEntry.user_id == user.id)
                    .order_by(CreditLedgerEntry.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        sessions = list(
            (
                await self.session.scalars(
                    select(AuthSession)
                    .where(AuthSession.user_id == user.id)
                    .order_by(AuthSession.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        notifications = list(
            (
                await self.session.scalars(
                    select(UserNotification)
                    .where(UserNotification.user_id == user.id)
                    .order_by(UserNotification.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        notes = list(
            (
                await self.session.scalars(
                    select(AdminUserNote)
                    .where(AdminUserNote.user_id == user.id)
                    .order_by(AdminUserNote.created_at.desc())
                    .limit(25)
                )
            ).all()
        )
        audit = list(
            (
                await self.session.scalars(
                    select(AuditLog)
                    .where(
                        or_(
                            AuditLog.actor_user_id == user.id,
                            and_(
                                AuditLog.resource_type == "user",
                                AuditLog.resource_id == str(user.id),
                            ),
                        )
                    )
                    .order_by(AuditLog.created_at.desc(), AuditLog.id.desc())
                    .limit(50)
                )
            ).all()
        )
        return AdminUserDetailData(
            user=user,
            entitlement=entitlement,
            balance=balance,
            latest_purchase_provider=provider,
            watches=watches,
            recordings=recordings,
            payments=payments,
            ledger=ledger,
            sessions=sessions,
            notifications=notifications,
            notes=notes,
            audit=audit,
        )

    async def create_user_note(
        self,
        *,
        actor_user_id: uuid.UUID,
        user_id: str,
        body: str,
    ) -> AdminUserNote:
        user = await self.get_user(user_id)
        note = AdminUserNote(
            user_id=user.id,
            author_user_id=actor_user_id,
            body=body.strip(),
        )
        self.session.add(note)
        await self.session.flush()
        return note

    async def update_user_note(
        self,
        *,
        actor_user_id: uuid.UUID,
        user_id: str,
        note_id: str,
        body: str,
    ) -> AdminUserNote:
        user = await self.get_user(user_id)
        try:
            parsed_note_id = uuid.UUID(note_id)
        except ValueError as exc:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Note not found", status_code=404) from exc
        note = await self.session.scalar(
            select(AdminUserNote).where(
                AdminUserNote.id == parsed_note_id,
                AdminUserNote.user_id == user.id,
            )
        )
        if note is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Note not found", status_code=404)
        note.body = body.strip()
        note.author_user_id = actor_user_id
        note.updated_at = utcnow()
        await self.session.flush()
        return note

    async def issue_identity_token(self, user_id: str, purpose: str) -> User:
        if purpose not in {"verify_email", "password_reset"}:
            raise ApplicationError("VALIDATION_ERROR", "Invalid identity token purpose", status_code=400)
        user = await self.get_user(user_id)
        if not user.is_active and purpose != "verify_email":
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Inactive user cannot receive a password reset",
                status_code=409,
            )
        if purpose == "verify_email" and user.email_verified_at is not None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Email is already verified",
                status_code=409,
            )
        now = utcnow()
        await self.session.execute(
            update(OneTimeToken)
            .where(
                OneTimeToken.user_id == user.id,
                OneTimeToken.purpose == purpose,
                OneTimeToken.consumed_at.is_(None),
            )
            .values(consumed_at=now)
        )
        token = OneTimeToken(
            id=uuid.uuid4(),
            user_id=user.id,
            purpose=purpose,
            expires_at=now + timedelta(seconds=self.settings.one_time_token_ttl_seconds),
        )
        self.session.add(token)
        await self.session.flush()
        await OutboxWriter().enqueue(
            self.session,
            topic=f"identity.email.{purpose}",
            aggregate_type="user",
            aggregate_id=str(user.id),
            payload={"token_id": str(token.id)},
        )
        return user

    async def force_logout(self, user_id: str) -> User:
        user = await self.get_user(user_id)
        now = utcnow()
        await self.session.execute(
            update(AuthSession)
            .where(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=now, revoked_reason="admin_force_logout")
        )
        return user

    async def update_display_name(self, user_id: str, display_name: str | None) -> tuple[User, str | None]:
        user = await self.get_user(user_id)
        previous = user.display_name
        user.display_name = display_name.strip() if display_name else None
        await self.session.flush()
        return user, previous

    async def cancel_deletion(self, user_id: str) -> User:
        user = await self.get_user(user_id)
        if user.deletion_requested_at is None or user.deletion_completed_at is not None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "User does not have a pending deletion request",
                status_code=409,
            )
        user.deletion_requested_at = None
        user.is_active = True
        await self.session.flush()
        return user

    async def global_search(self, query: str, *, limit: int = 20) -> list[dict[str, str | None]]:
        term = query.strip()
        if len(term) < 2:
            raise ApplicationError(
                "VALIDATION_ERROR", "Search query must contain at least 2 characters", status_code=400
            )
        hits: list[dict[str, str | None]] = []
        users = list(
            (
                await self.session.scalars(
                    select(User)
                    .where(User.normalized_email.ilike(f"%{term.lower()}%"))
                    .order_by(User.created_at.desc())
                    .limit(min(limit, 8))
                )
            ).all()
        )
        for user in users:
            hits.append(
                {
                    "type": "user",
                    "id": str(user.id),
                    "label": user.email,
                    "detail": user.display_name,
                    "href": f"/admin/users/{user.id}",
                }
            )
        try:
            parsed = uuid.UUID(term)
        except ValueError:
            parsed = None
        if parsed is not None:
            exact_user = await self.session.get(User, parsed)
            if exact_user is not None and not any(
                item["id"] == str(exact_user.id) for item in hits
            ):
                hits.append(
                    {
                        "type": "user",
                        "id": str(exact_user.id),
                        "label": exact_user.email,
                        "detail": "User ID",
                        "href": f"/admin/users/{exact_user.id}",
                    }
                )
            payment = await self.session.get(PaymentOrder, parsed)
            if payment is not None:
                hits.append(
                    {
                        "type": "payment_order",
                        "id": str(payment.id),
                        "label": f"Payment {payment.id}",
                        "detail": payment.status,
                        "href": f"/admin/users/{payment.user_id}",
                    }
                )
            recording = await self.session.get(Recording, parsed)
            if recording is not None:
                hits.append(
                    {
                        "type": "recording",
                        "id": str(recording.id),
                        "label": f"Recording {recording.id}",
                        "detail": recording.status,
                        "href": f"/admin/jobs/{recording.id}",
                    }
                )
        request_rows = list(
            (
                await self.session.scalars(
                    select(AuditLog)
                    .where(AuditLog.request_id == term)
                    .order_by(AuditLog.created_at.desc())
                    .limit(5)
                )
            ).all()
        )
        for row in request_rows:
            hits.append(
                {
                    "type": "request",
                    "id": row.request_id or str(row.id),
                    "label": f"Request {row.request_id}",
                    "detail": row.action,
                    "href": "/admin/errors",
                }
            )
        return hits[:limit]

    async def list_privacy_requests(
        self,
        *,
        limit: int = 100,
    ) -> list[dict[str, object]]:
        deletion_users = list(
            (
                await self.session.scalars(
                    select(User)
                    .where(User.deletion_requested_at.is_not(None))
                    .order_by(User.deletion_requested_at.desc())
                    .limit(limit)
                )
            ).all()
        )
        export_logs = list(
            (
                await self.session.scalars(
                    select(AuditLog)
                    .where(AuditLog.action == "admin.user.privacy_exported")
                    .order_by(AuditLog.created_at.desc())
                    .limit(limit)
                )
            ).all()
        )
        cancel_logs = list(
            (
                await self.session.scalars(
                    select(AuditLog)
                    .where(AuditLog.action == "admin.user.deletion_cancelled")
                    .order_by(AuditLog.created_at.desc())
                    .limit(limit)
                )
            ).all()
        )
        items: list[dict[str, object]] = []
        for user in deletion_users:
            requested_at = user.deletion_requested_at
            if requested_at is None:
                continue
            items.append(
                {
                    "id": f"delete:{user.id}:{int(_aware(requested_at).timestamp())}",
                    "user_id": str(user.id),
                    "email": user.email,
                    "kind": "delete",
                    "status": "completed" if user.deletion_completed_at else "pending",
                    "requested_at": requested_at,
                    "completed_at": user.deletion_completed_at,
                    "cancelled_at": None,
                }
            )
        for log in export_logs:
            if log.resource_id is None:
                continue
            try:
                target_id = uuid.UUID(log.resource_id)
            except ValueError:
                continue
            target = await self.session.get(User, target_id)
            items.append(
                {
                    "id": f"export:{log.id}",
                    "user_id": str(target_id),
                    "email": target.email if target is not None else "deleted user",
                    "kind": "export",
                    "status": "completed",
                    "requested_at": log.created_at,
                    "completed_at": log.created_at,
                    "cancelled_at": None,
                }
            )
        for log in cancel_logs:
            if log.resource_id is None:
                continue
            try:
                target_id = uuid.UUID(log.resource_id)
            except ValueError:
                continue
            target = await self.session.get(User, target_id)
            items.append(
                {
                    "id": f"delete-cancel:{log.id}",
                    "user_id": str(target_id),
                    "email": target.email if target is not None else "deleted user",
                    "kind": "delete",
                    "status": "cancelled",
                    "requested_at": log.created_at,
                    "completed_at": None,
                    "cancelled_at": log.created_at,
                }
            )
        items.sort(key=lambda item: _aware(item["requested_at"]), reverse=True)  # type: ignore[arg-type]
        return items[:limit]

    @staticmethod
    def _user_not_found() -> ApplicationError:
        return ApplicationError("RESOURCE_NOT_FOUND", "User not found", status_code=404)

    @staticmethod
    def _recording_not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND", "Recording not found", status_code=404
        )
