"""Email copies of notifications, and replies to Partner Program applicants.

Every email is logged in admin_email_logs (Admin → Operations). Notification
emails are optional: each kind has a switch in Settings → Notifications, a
one-click unsubscribe link, and these anti-spam limits:

* "channel went LIVE": at most one email per channel every 6 hours;
* per user: at most 6 notification emails an hour and 20 a day. Anything over
  is logged as `suppressed` and only shown in the app.
"""

from __future__ import annotations

import asyncio
import uuid
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.credits.service import CreditService
from app.application.recordings.retention import has_paid_purchase
from app.application.notifications.service import (
    EMAIL_PREFERENCE_FOR_KIND,
    email_enabled_for,
)
from app.application.notifications.unsubscribe import EMAIL_LABELS, make_token
from app.infrastructure.db.admin_models import AdminEmailLog, PartnerApplication
from app.infrastructure.db.models import NotificationPreference, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.email import templates
from app.infrastructure.email.templates import RenderedEmail
from app.settings import AppSettings, get_app_settings

LIVE_COOLDOWN = timedelta(hours=6)
HOURLY_CAP = 6
DAILY_CAP = 20

Sender = Callable[..., None]


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _smtp_sender(settings: AppSettings) -> Sender:
    from app.infrastructure.email.smtp import SMTPEmailSender

    return SMTPEmailSender(settings).send


async def _handle_and_link(
    session: AsyncSession,
    *,
    kind: str,
    resource_type: str | None,
    resource_id: str | None,
    settings: AppSettings,
) -> tuple[str, str]:
    site = settings.frontend_base_url.rstrip("/")
    parsed: uuid.UUID | None = None
    if resource_id:
        try:
            parsed = uuid.UUID(resource_id)
        except ValueError:
            parsed = None
    if kind in ("credits_low", "cloud_minutes_exhausted"):
        return "SaveStream", f"{site}/billing"
    if resource_type == "watch" and parsed:
        watch = await session.get(Watch, parsed)
        if watch is not None:
            source = (watch.resolved_username or watch.source_value).lstrip("@")
            return f"@{source}", f"{site}/channels/{watch.id}"
    if resource_type == "recording" and parsed:
        recording = await session.get(Recording, parsed)
        if recording is not None:
            source = (recording.resolved_username or recording.source_value).lstrip("@")
            return f"@{source}", f"{site}/recordings/{recording.id}"
    return "SaveStream", f"{site}/notifications"


async def _log(
    session: AsyncSession,
    *,
    dedupe_key: str,
    user_id: uuid.UUID | None,
    recipient: str,
    kind: str,
    subject: str,
) -> AdminEmailLog | None:
    """The log row for this email, or None when it was already sent."""
    log = await session.scalar(select(AdminEmailLog).where(AdminEmailLog.dedupe_key == dedupe_key))
    if log is not None and log.status in ("sent", "suppressed"):
        return None
    if log is None:
        log = AdminEmailLog(
            user_id=user_id,
            recipient_email=recipient,
            kind=kind,
            subject=subject[:240],
            status="sending",
            dedupe_key=dedupe_key[:180],
            attempts=1,
        )
        session.add(log)
    else:
        log.status = "sending"
        log.error = None
        log.attempts += 1
    await session.commit()
    return log


async def _send(
    session: AsyncSession,
    log: AdminEmailLog,
    send: Sender,
    *,
    to: str,
    email: RenderedEmail,
    headers: dict[str, str] | None = None,
) -> str:
    try:
        await asyncio.to_thread(
            send, to=to, subject=email.subject, text=email.text, html=email.html, headers=headers
        )
    except Exception as exc:
        log.status = "failed"
        log.error = (str(exc) or type(exc).__name__)[:4000]
        await session.commit()
        raise
    log.status = "sent"
    log.sent_at = utcnow()
    await session.commit()
    return "sent"


async def _recent_count(
    session: AsyncSession, *, user_id: uuid.UUID, since: datetime, dedupe_prefix: str = "notify:"
) -> int:
    return int(
        await session.scalar(
            select(func.count())
            .select_from(AdminEmailLog)
            .where(
                AdminEmailLog.user_id == user_id,
                AdminEmailLog.status == "sent",
                AdminEmailLog.dedupe_key.startswith(dedupe_prefix),
                AdminEmailLog.created_at >= since,
            )
        )
        or 0
    )


async def send_notification_email(
    session: AsyncSession,
    settings: AppSettings,
    payload: dict[str, str],
    *,
    send: Sender | None = None,
    now: datetime | None = None,
) -> str:
    """Send one notification email (outbox `notification.email` payload).
    Returns what happened: sent, disabled, duplicate, cooldown, rate_limited
    or skipped (unknown kind, inactive or unverified account)."""
    kind = payload.get("kind", "")
    if kind not in EMAIL_PREFERENCE_FOR_KIND:
        return "skipped"
    try:
        user_id = uuid.UUID(payload.get("user_id", ""))
    except ValueError:
        return "skipped"
    user = await session.get(User, user_id)
    if user is None or not user.is_active or user.email_verified_at is None:
        return "skipped"
    preferences = await session.get(NotificationPreference, user.id)
    if not email_enabled_for(preferences, kind):
        return "disabled"

    current = now or utcnow()
    resource_type = payload.get("resource_type") or None
    resource_id = payload.get("resource_id") or None
    resource = resource_id or "-"
    dedupe_key = payload.get("dedupe_key") or f"notify:{kind}:{resource}:{uuid.uuid4()}"
    handle, link = await _handle_and_link(
        session,
        kind=kind,
        resource_type=resource_type,
        resource_id=resource_id,
        settings=settings,
    )
    preference = EMAIL_PREFERENCE_FOR_KIND[kind]
    token = make_token(settings.jwt_secret, user.id, preference)
    site = settings.frontend_base_url.rstrip("/")
    api = (settings.public_api_base_url or site).rstrip("/")
    available = (
        (await CreditService(session).balance(user.id)).available if kind == "credits_low" else None
    )
    email = templates.notification_email(
        kind,
        handle=handle,
        link=link,
        site_url=site,
        unsubscribe_url=f"{site}/unsubscribe?token={token}",
        unsubscribe_label=EMAIL_LABELS[preference],
        available_minutes=available,
        trial=kind == "cloud_minutes_exhausted"
        and not await has_paid_purchase(session, user.id),
    )
    if email is None:
        return "skipped"

    reason: str | None = None
    if kind == "creator_live" and await _recent_count(
        session,
        user_id=user.id,
        since=current - LIVE_COOLDOWN,
        dedupe_prefix=f"notify:creator_live:{resource}:",
    ):
        reason = "cooldown"
    elif await _recent_count(session, user_id=user.id, since=current - timedelta(hours=1)) >= HOURLY_CAP:
        reason = "rate_limited"
    elif await _recent_count(session, user_id=user.id, since=current - timedelta(days=1)) >= DAILY_CAP:
        reason = "rate_limited"

    log = await _log(
        session,
        dedupe_key=dedupe_key,
        user_id=user.id,
        recipient=user.email,
        kind=f"notify.{kind}",
        subject=email.subject,
    )
    if log is None:
        return "duplicate"
    if reason is not None:
        log.status = "suppressed"
        log.error = reason
        await session.commit()
        return reason
    return await _send(
        session,
        log,
        send or _smtp_sender(settings),
        to=user.email,
        email=email,
        headers={
            "List-Unsubscribe": f"<{api}/v1/public/email/unsubscribe?token={token}>",
            "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
        },
    )


async def send_partner_email(
    session: AsyncSession,
    settings: AppSettings,
    application_id: str,
    kind: str,
    *,
    send: Sender | None = None,
) -> str:
    from app.application.public_reports import report_reference

    try:
        parsed = uuid.UUID(application_id)
    except ValueError:
        return "skipped"
    application = await session.get(PartnerApplication, parsed)
    if application is None:
        return "skipped"
    reference = "PA-" + report_reference(application.id).removeprefix("SR-")
    email = templates.partner_email(
        kind,
        name=application.name,
        reference=reference,
        site_url=settings.frontend_base_url.rstrip("/"),
    )
    if email is None:
        return "skipped"
    log = await _log(
        session,
        dedupe_key=f"partner:{application.id}:{kind}",
        user_id=None,
        recipient=application.email,
        kind=kind,
        subject=email.subject,
    )
    if log is None:
        return "duplicate"
    return await _send(session, log, send or _smtp_sender(settings), to=application.email, email=email)


async def send_account_email(
    session: AsyncSession,
    settings: AppSettings,
    payload: dict[str, str],
    *,
    send: Sender | None = None,
) -> str:
    """Required email about a suspension, termination or reinstatement."""
    try:
        user_id = uuid.UUID(payload.get("user_id", ""))
    except ValueError:
        return "skipped"
    user = await session.get(User, user_id)
    if user is None:
        return "skipped"
    kind = payload.get("kind", "")
    email: templates.RenderedEmail | None
    if kind == "channel_verification_needed":
        # Required service notice: recording stops for unverified channels.
        email = templates.message_email(
            subject=payload.get("subject", "Verify your channel to keep recording"),
            body=payload.get("body", ""),
            site_url=settings.frontend_base_url.rstrip("/"),
        )
    else:
        email = templates.account_status_email(
            kind,
            reason=user.account_status_reason or "",
            reference=user.account_status_reference,
            site_url=settings.frontend_base_url.rstrip("/"),
        )
    if email is None:
        return "skipped"
    log = await _log(
        session,
        dedupe_key=f"account:{user.id}:{kind}:{payload.get('changed_at', '')}",
        user_id=user.id,
        recipient=user.email,
        kind=kind,
        subject=email.subject,
    )
    if log is None:
        return "duplicate"
    return await _send(session, log, send or _smtp_sender(settings), to=user.email, email=email)


async def _with_session(callback, settings: AppSettings | None):
    cfg = settings or get_app_settings()
    database = Database(cfg.database_url)
    try:
        async with database.session() as session:
            return await callback(session, cfg)
    finally:
        await database.close()


def run_notification_email(payload: dict[str, str]) -> str:
    return asyncio.run(_with_session(lambda s, c: send_notification_email(s, c, payload), None))


def run_partner_email(application_id: str, kind: str) -> str:
    return asyncio.run(
        _with_session(lambda s, c: send_partner_email(s, c, application_id, kind), None)
    )


def run_account_email(payload: dict[str, str]) -> str:
    return asyncio.run(_with_session(lambda s, c: send_account_email(s, c, payload), None))
