from __future__ import annotations

from dataclasses import replace

from app.infrastructure.email import smtp as smtp_module
from app.infrastructure.email import templates
from app.infrastructure.email.smtp import SMTPEmailSender
from tests.identity_helpers import identity_settings

LINK = "https://savestream.online/verify-email?token=abc%2Edef&x=<1>"


def test_verify_email_renders_text_and_html_with_escaped_link() -> None:
    email = templates.verify_email(
        link=LINK,
        expires_in_seconds=1800,
        site_url="https://savestream.online",
        trial_credits=10,
    )
    assert email.subject == "Verify your SaveStream email"
    assert LINK in email.text
    assert "expires in 30 minutes" in email.text
    assert "10 free trial credits" in email.text
    assert 'href="https://savestream.online/verify-email?token=abc%2Edef&amp;x=&lt;1&gt;"' in email.html
    assert "<1>" not in email.html
    assert ">Verify email</a>" in email.html
    assert "support@savestream.online" in email.html


def test_verify_email_omits_trial_when_disabled_and_reset_copy() -> None:
    verify = templates.verify_email(link=LINK, expires_in_seconds=3600, site_url="https://x.test")
    assert "free trial" not in verify.text
    assert "expires in 1 hour" in verify.text

    reset = templates.password_reset(link=LINK, expires_in_seconds=1800, site_url="https://x.test")
    assert reset.subject == "Reset your SaveStream password"
    assert ">Reset password</a>" in reset.html
    assert "your password will not change" in reset.text


def test_sender_builds_multipart_alternative(monkeypatch) -> None:
    sent = []

    class FakeSMTP:
        def __init__(self, *args, **kwargs) -> None:
            del args, kwargs

        def __enter__(self):
            return self

        def __exit__(self, *exc) -> None:
            return None

        def starttls(self, **kwargs) -> None:
            del kwargs

        def login(self, *args) -> None:
            del args

        def send_message(self, message) -> None:
            sent.append(message)

    monkeypatch.setattr(smtp_module.smtplib, "SMTP", FakeSMTP)
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        email_from="SaveStream <no-reply@savestream.online>",
    )
    email = templates.verify_email(link=LINK, expires_in_seconds=1800, site_url="https://x.test")
    SMTPEmailSender(settings).send(
        to="user@example.com", subject=email.subject, text=email.text, html=email.html
    )

    message = sent[0]
    assert message.get_content_type() == "multipart/alternative"
    parts = [part.get_content_type() for part in message.iter_parts()]
    assert parts == ["text/plain", "text/html"]

    SMTPEmailSender(settings).send(to="ops@example.com", subject="alert", text="plain only")
    assert sent[1].get_content_type() == "text/plain"
