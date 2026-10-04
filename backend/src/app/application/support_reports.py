from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import AdminSupportReport
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(report: AdminSupportReport) -> str:
    payload = json.dumps(
        {"created_at": _aware(report.created_at).isoformat(), "id": str(report.id)},
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
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


class SupportReportService:
    RETENTION_DAYS = 180
    STATUSES = {"new", "reviewing", "resolved", "closed"}

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        description: str,
        recording_id: str | None,
        diagnostic_log: dict[str, object],
        app_version: str | None,
        platform: str | None,
    ) -> AdminSupportReport:
        parsed_recording_id: uuid.UUID | None = None
        if recording_id:
            try:
                parsed_recording_id = uuid.UUID(recording_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid recording id",
                    status_code=400,
                ) from exc
            recording = await self.session.get(Recording, parsed_recording_id)
            if recording is None or recording.user_id != user_id:
                raise ApplicationError(
                    "RESOURCE_NOT_FOUND",
                    "Recording not found",
                    status_code=404,
                )

        report = AdminSupportReport(
            user_id=user_id,
            recording_id=parsed_recording_id,
            description=description.strip(),
            diagnostic_log=diagnostic_log,
            app_version=app_version.strip() if app_version else None,
            platform=platform.strip().casefold() if platform else None,
            status="new",
            expires_at=utcnow() + timedelta(days=self.RETENTION_DAYS),
        )
        self.session.add(report)
        await self.session.flush()
        return report

    async def get_admin_report(
        self,
        report_id: str,
    ) -> tuple[AdminSupportReport, str]:
        try:
            parsed = uuid.UUID(report_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Support report not found",
                status_code=404,
            ) from exc
        row = (
            await self.session.execute(
                select(AdminSupportReport, User.email)
                .join(User, User.id == AdminSupportReport.user_id)
                .where(AdminSupportReport.id == parsed)
            )
        ).one_or_none()
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Support report not found",
                status_code=404,
            )
        return row[0], row[1]

    async def list_admin_reports(
        self,
        *,
        limit: int,
        cursor: str | None,
        status: str | None,
        assigned_to_user_id: str | None,
        query: str | None,
    ) -> tuple[list[tuple[AdminSupportReport, str]], str | None, bool]:
        statement = (
            select(AdminSupportReport, User.email)
            .join(User, User.id == AdminSupportReport.user_id)
            .where(AdminSupportReport.expires_at > utcnow())
        )
        if status:
            if status not in self.STATUSES:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid support report status",
                    status_code=400,
                )
            statement = statement.where(AdminSupportReport.status == status)
        if assigned_to_user_id:
            try:
                assigned = uuid.UUID(assigned_to_user_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid assignee id",
                    status_code=400,
                ) from exc
            statement = statement.where(
                AdminSupportReport.assigned_to_user_id == assigned
            )
        if query:
            needle = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    User.email.ilike(needle),
                    AdminSupportReport.description.ilike(needle),
                )
            )
        if cursor:
            created_at, report_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    AdminSupportReport.created_at < created_at,
                    and_(
                        AdminSupportReport.created_at == created_at,
                        AdminSupportReport.id < report_id,
                    ),
                )
            )
        raw_rows = list(
            (
                await self.session.execute(
                    statement.order_by(
                        AdminSupportReport.created_at.desc(),
                        AdminSupportReport.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        rows = [(row[0], row[1]) for row in raw_rows]
        has_more = len(rows) > limit
        page = rows[:limit]
        next_cursor = (
            _encode_cursor(page[-1][0]) if has_more and page else None
        )
        return page, next_cursor, has_more

    async def update_admin_report(
        self,
        *,
        report_id: str,
        status: str,
        assigned_to_user_id: str | None,
    ) -> tuple[AdminSupportReport, str, dict[str, object]]:
        if status not in self.STATUSES:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid support report status",
                status_code=400,
            )
        report, email = await self.get_admin_report(report_id)
        before: dict[str, object] = {
            "status": report.status,
            "assigned_to_user_id": (
                str(report.assigned_to_user_id)
                if report.assigned_to_user_id
                else None
            ),
        }
        assigned: uuid.UUID | None = None
        if assigned_to_user_id:
            try:
                assigned = uuid.UUID(assigned_to_user_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid assignee id",
                    status_code=400,
                ) from exc
        report.status = status
        report.assigned_to_user_id = assigned
        report.resolved_at = utcnow() if status in {"resolved", "closed"} else None
        await self.session.flush()
        return report, email, before
