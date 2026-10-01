from __future__ import annotations

import smtplib
import ssl
import uuid
from datetime import datetime, timezone
from email.message import EmailMessage
from urllib.parse import quote

from app.infrastructure.db.models import OneTimeToken, User
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

    def send(self, *, to: str, subject: str, text: str) -> None:
        message = EmailMessage()
        message["From"] = self.settings.email_from
        message["To"] = to
        message["Subject"] = subject
        message.set_content(text)
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
            if token_row.purpose == "verify_email":
                subject = "Verify your SaveStream email"
                link = f"{cfg.frontend_base_url}/verify-email?token={encoded}"
                body = f"Open this link to verify your SaveStream email:\n\n{link}\n"
            elif token_row.purpose == "password_reset":
                subject = "Reset your SaveStream password"
                link = f"{cfg.frontend_base_url}/reset-password?token={encoded}"
                body = f"Open this link to reset your SaveStream password:\n\n{link}\n"
            else:
                return

            SMTPEmailSender(cfg).send(
                to=user.email,
                subject=subject,
                text=body,
            )
    finally:
        await database.close()
