from __future__ import annotations

from dataclasses import dataclass
from html import escape

BRAND = "#4F46E5"
SUPPORT_EMAIL = "support@savestream.online"


@dataclass(frozen=True, slots=True)
class RenderedEmail:
    subject: str
    text: str
    html: str


def _duration(seconds: int) -> str:
    minutes = max(1, round(seconds / 60))
    if minutes % 60 == 0:
        hours = minutes // 60
        return f"{hours} hour{'s' if hours != 1 else ''}"
    return f"{minutes} minute{'s' if minutes != 1 else ''}"


def action_email(
    *,
    subject: str,
    heading: str,
    intro: str,
    button_label: str,
    link: str,
    expires_in_seconds: int,
    ignore_note: str,
    site_url: str,
) -> RenderedEmail:
    """Transactional email with a single call-to-action link.

    Table layout and inline styles only, no images, so it renders in Gmail,
    Outlook, and Apple Mail with images blocked.
    """
    expires = f"This link expires in {_duration(expires_in_seconds)}."
    text = (
        f"{heading}\n\n{intro}\n\n{button_label}:\n{link}\n\n{expires}\n{ignore_note}\n\n"
        f"Questions? Contact {SUPPORT_EMAIL}.\n— SaveStream\n"
    )
    href = escape(link, quote=True)
    site = escape(site_url, quote=True)
    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>{escape(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#f4f4f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1f2330;">
<div style="display:none;max-height:0;overflow:hidden;">{escape(intro)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f7;padding:32px 16px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">
<tr><td style="padding:0 4px 20px;">
<table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td style="background:{BRAND};border-radius:8px;width:32px;height:32px;text-align:center;font-weight:700;font-size:18px;color:#ffffff;">S</td>
<td style="padding-left:10px;font-weight:600;font-size:17px;color:#1f2330;">SaveStream</td>
</tr></table>
</td></tr>
<tr><td style="background:#ffffff;border:1px solid #e6e6ec;border-radius:12px;padding:32px;">
<h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;color:#1f2330;">{escape(heading)}</h1>
<p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#4a4f5c;">{escape(intro)}</p>
<table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td style="border-radius:8px;background:{BRAND};">
<a href="{href}" style="display:inline-block;padding:12px 24px;font-size:15px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:8px;">{escape(button_label)}</a>
</td></tr></table>
<p style="margin:24px 0 0;font-size:13px;line-height:1.6;color:#6b7080;">{escape(expires)} {escape(ignore_note)}</p>
<p style="margin:20px 0 0;padding-top:20px;border-top:1px solid #eeeef3;font-size:12px;line-height:1.6;color:#8a8f9c;">If the button does not work, copy and paste this link into your browser:<br><a href="{href}" style="color:{BRAND};word-break:break-all;">{escape(link)}</a></p>
</td></tr>
<tr><td style="padding:20px 4px 0;font-size:12px;line-height:1.6;color:#8a8f9c;">
SaveStream · Cloud recording for TikTok channels you own, manage, or have permission to record.<br>
<a href="{site}" style="color:#8a8f9c;">{escape(site_url.removeprefix("https://"))}</a> · <a href="mailto:{SUPPORT_EMAIL}" style="color:#8a8f9c;">{SUPPORT_EMAIL}</a>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>
"""
    return RenderedEmail(subject=subject, text=text, html=html)


def verify_email(
    *, link: str, expires_in_seconds: int, site_url: str, trial_credits: int = 0
) -> RenderedEmail:
    trial = f" and get {trial_credits} free trial credits" if trial_credits > 0 else ""
    return action_email(
        subject="Verify your SaveStream email",
        heading="Confirm your email address",
        intro=f"Thanks for signing up for SaveStream. Confirm your email to activate your account{trial}.",
        button_label="Verify email",
        link=link,
        expires_in_seconds=expires_in_seconds,
        ignore_note="If you didn’t create a SaveStream account, you can ignore this email.",
        site_url=site_url,
    )


def password_reset(*, link: str, expires_in_seconds: int, site_url: str) -> RenderedEmail:
    return action_email(
        subject="Reset your SaveStream password",
        heading="Reset your password",
        intro="We received a request to reset the password for your SaveStream account. Choose a new password using the button below.",
        button_label="Reset password",
        link=link,
        expires_in_seconds=expires_in_seconds,
        ignore_note="If you didn’t request a password reset, you can ignore this email; your password will not change.",
        site_url=site_url,
    )
