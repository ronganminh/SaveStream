from __future__ import annotations

import smtplib
import ssl
import uuid
from datetime import datetime, timezone
from email.message import EmailMessage
from urllib.parse import quote

from sqlalchemy import select

from app.application.runtime_settings import RuntimeSettingsService
from app.infrastructure.db.admin_models import AdminEmailLog, AdminEmailTemplate
from app.infrastructure.db.models import OneTimeToken, User
from app.infrastructure.email import templates
from app.infrastructure.db.session import Database
from app.infrastructure.security.tokens import TokenService
from app.settings import AppSettings, get_app_settings


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


class SMTPEmailSender:
    def __init__(self, settings: AppSettings) -> None:
        self.settings = settings

    def send(self, *, to: str, subject: str, text: str, html: str | None = None) -> None:
        message = EmailMessage()
        message["From"] = self.settings.email_from
        message["To"] = to
        message["Subject"] = subject
        message.set_content(text)
        if html is not None:
            message.add_alternative(html, subtype="html")
        with smtplib.SMTP(
            self.settings.smtp_host,
            self.settings.smtp_port,
            timeout=10,
        ) as smtp:
            if self.settings.smtp_starttls:
                smtp.starttls(context=ssl.create_default_context())
            if self.settings.smtp_username:
                if not self.settings.smtp_password:
                    raise RuntimeError("SMTP password is required when username is configured")
                smtp.login(
                    self.settings.smtp_username,
                    self.settings.smtp_password,
                )
            smtp.send_message(message)


async def deliver_one_time_token_email(
    token_id: str,
    settings: AppSettings | None = None,
) -> None:
    cfg = settings or get_app_settings()
    database = Database(cfg.database_url)
    try:
        async with database.session() as session:
            try:
                parsed_id = uuid.UUID(token_id)
            except ValueError:
                return
            token_row = await session.get(OneTimeToken, parsed_id)
            if token_row is None or token_row.consumed_at is not None:
                return
            if _aware(token_row.expires_at) <= datetime.now(timezone.utc):
                return
            user = await session.get(User, token_row.user_id)
            if user is None or not user.is_active:
                return

            raw_token = TokenService(cfg).issue_one_time_token(
                token_id=token_row.id,
                user_id=user.id,
                purpose=token_row.purpose,
                issued_at=_aware(token_row.created_at),
                expires_at=_aware(token_row.expires_at),
            )
            encoded = quote(raw_token, safe="")
            expires_in = int(
                (_aware(token_row.expires_at) - _aware(token_row.created_at)).total_seconds()
            )
            override = await session.get(AdminEmailTemplate, token_row.purpose)
            subject_override = override.subject if override is not None else None
            body_override = override.body if override is not None else None
            if token_row.purpose == "verify_email":
                signup_credits = await RuntimeSettingsService(
                    session, cfg
                ).integer("signup_credits")
                email = templates.verify_email(
                    link=f"{cfg.frontend_base_url}/verify-email?token={encoded}",
                    expires_in_seconds=expires_in,
                    site_url=cfg.frontend_base_url,
                    trial_credits=signup_credits,
                    subject_override=subject_override,
                    intro_override=body_override,
                )
            elif token_row.purpose == "password_reset":
                email = templates.password_reset(
                    link=f"{cfg.frontend_base_url}/reset-password?token={encoded}",
                    expires_in_seconds=expires_in,
                    site_url=cfg.frontend_base_url,
                    subject_override=subject_override,
                    intro_override=body_override,
                )
            else:
                return

            dedupe_key = f"identity:{token_row.id}"
            log = await session.scalar(
                select(AdminEmailLog).where(AdminEmailLog.dedupe_key == dedupe_key)
            )
            if log is not None and log.status == "sent":
                return
            if log is None:
                log = AdminEmailLog(
                    user_id=user.id,
                    recipient_email=user.email,
                    kind=token_row.purpose,
                    subject=email.subject,
                    status="sending",
                    dedupe_key=dedupe_key,
                    attempts=1,
                )
                session.add(log)
            else:
                log.status = "sending"
                log.error = None
                log.attempts += 1
                log.subject = email.subject
            await session.commit()
            try:
                SMTPEmailSender(cfg).send(
                    to=user.email,
                    subject=email.subject,
                    text=email.text,
                    html=email.html,
                )
            except Exception as exc:
                log.status = "failed"
                log.error = (str(exc) or type(exc).__name__)[:4000]
                await session.commit()
                raise
            log.status = "sent"
            log.sent_at = datetime.now(timezone.utc)
            await session.commit()
    finally:
        await database.close()
