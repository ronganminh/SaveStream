from __future__ import annotations

from dataclasses import dataclass
from html import escape

BRAND = "#6D4AFF"
INK = "#15122B"
MUTED = "#56526F"
LINE = "#E6E1F4"
PAGE = "#F8F7FC"
LINK = "#5330F0"
FONT = "'Plus Jakarta Sans',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
SUPPORT_EMAIL = "support@savestream.online"
# Same value as apps/web/src/lib/support.ts.
SUPPORT_RESPONSE_TIME = "2 business days"


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


def _shell(*, subject: str, preheader: str, content: str, site_url: str, footer_note: str) -> str:
    """Shared layout (Claude Design email template): white card with a brand
    top rule, logo header, content, and a centered footer. Tables and inline
    styles only, no images, so it renders with images blocked."""
    site = escape(site_url, quote=True)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>{escape(subject)}</title>
</head>
<body style="margin:0;padding:0;background:{PAGE};font-family:{FONT};color:{INK};">
<div style="display:none;max-height:0;overflow:hidden;">{escape(preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{PAGE};">
<tr><td align="center" style="padding:32px 16px 0;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border:1px solid {LINE};border-radius:20px;border-collapse:separate;">
<tr><td style="padding:20px 32px;border-top:4px solid {BRAND};border-bottom:1px solid {LINE};border-radius:20px 20px 0 0;">
<table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td style="background:{BRAND};border-radius:9px;width:28px;height:28px;text-align:center;font-weight:800;font-size:15px;color:#ffffff;">S</td>
<td style="padding-left:10px;font-weight:800;font-size:18px;letter-spacing:-0.02em;color:{INK};">SaveStream</td>
</tr></table>
</td></tr>
<tr><td style="padding:32px;">
{content}
</td></tr>
</table>
</td></tr>
<tr><td align="center" style="padding:24px 32px 40px;font-size:12px;line-height:1.7;color:{MUTED};">
SaveStream · Cloud recording for TikTok channels you own, manage, or have permission to record.<br>
<a href="{site}" style="color:{MUTED};">{escape(site_url.removeprefix("https://"))}</a><br>
Questions? <a href="mailto:{SUPPORT_EMAIL}" style="color:{LINK};">{SUPPORT_EMAIL}</a> · we usually reply within {SUPPORT_RESPONSE_TIME}.{f"<br>{escape(footer_note)}" if footer_note else ""}
</td></tr>
</table>
</body>
</html>
"""


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
        f"Questions? Contact {SUPPORT_EMAIL}; we usually reply within {SUPPORT_RESPONSE_TIME}.\n— SaveStream\n"
    )
    href = escape(link, quote=True)
    content = f"""<h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;font-weight:800;letter-spacing:-0.02em;color:{INK};">{escape(heading)}</h1>
<p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:{INK};">{escape(intro)}</p>
<table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td style="border-radius:12px;background:{BRAND};">
<a href="{href}" style="display:inline-block;padding:13px 24px;font-size:15px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:12px;">{escape(button_label)}</a>
</td></tr></table>
<p style="margin:24px 0 0;font-size:13px;line-height:1.6;color:{MUTED};">{escape(expires)} {escape(ignore_note)}</p>
<p style="margin:20px 0 0;padding-top:20px;border-top:1px solid {LINE};font-size:12px;line-height:1.6;color:{MUTED};">If the button does not work, copy and paste this link into your browser:<br><a href="{href}" style="color:{LINK};word-break:break-all;">{escape(link)}</a></p>"""
    html = _shell(
        subject=subject,
        preheader=intro,
        content=content,
        site_url=site_url,
        footer_note="This is a required account email, so it can’t be turned off.",
    )
    return RenderedEmail(subject=subject, text=text, html=html)


def verify_email(
    *,
    link: str,
    expires_in_seconds: int,
    site_url: str,
    trial_credits: int = 0,
    subject_override: str | None = None,
    intro_override: str | None = None,
) -> RenderedEmail:
    trial = f" and get {trial_credits} free trial credits" if trial_credits > 0 else ""
    return action_email(
        subject=subject_override or "Verify your SaveStream email",
        heading="Confirm your email address",
        intro=intro_override
        or f"Thanks for signing up for SaveStream. Confirm your email to activate your account{trial}.",
        button_label="Verify email",
        link=link,
        expires_in_seconds=expires_in_seconds,
        ignore_note="If you didn’t create a SaveStream account, you can ignore this email.",
        site_url=site_url,
    )


def password_reset(
    *,
    link: str,
    expires_in_seconds: int,
    site_url: str,
    subject_override: str | None = None,
    intro_override: str | None = None,
) -> RenderedEmail:
    return action_email(
        subject=subject_override or "Reset your SaveStream password",
        heading="Reset your password",
        intro=intro_override
        or "We received a request to reset the password for your SaveStream account. Choose a new password using the button below.",
        button_label="Reset password",
        link=link,
        expires_in_seconds=expires_in_seconds,
        ignore_note="If you didn’t request a password reset, you can ignore this email; your password will not change.",
        site_url=site_url,
    )



EMAIL_TEMPLATE_DEFAULTS: dict[str, tuple[str, str]] = {
    "verify_email": (
        "Verify your SaveStream email",
        "Thanks for signing up for SaveStream. Confirm your email to activate your account.",
    ),
    "password_reset": (
        "Reset your SaveStream password",
        "We received a request to reset the password for your SaveStream account. Choose a new password using the button below.",
    ),
}


def message_email(*, subject: str, body: str, site_url: str) -> RenderedEmail:
    text = f"{subject}\n\n{body}\n\n— SaveStream\n{site_url}\n"
    content = f"""<h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;font-weight:800;letter-spacing:-0.02em;color:{INK};">{escape(subject)}</h1>
<p style="margin:0;font-size:15px;line-height:1.7;color:{INK};white-space:pre-line;">{escape(body)}</p>"""
    html = _shell(
        subject=subject, preheader=body[:140], content=content, site_url=site_url, footer_note=""
    )
    return RenderedEmail(subject=subject, text=text, html=html)


def _notification_shell(
    *,
    subject: str,
    heading: str,
    intro: str,
    button_label: str,
    link: str,
    site_url: str,
    unsubscribe_url: str | None,
    unsubscribe_label: str | None,
    detail: str = "",
) -> RenderedEmail:
    """Notification email: heading, short text, one button. Optional emails
    end with a one-click unsubscribe link for just this kind."""
    href = escape(link, quote=True)
    detail_html = (
        f'<p style="margin:0 0 24px;font-size:14px;line-height:1.6;color:{MUTED};">{escape(detail)}</p>'
        if detail
        else ""
    )
    content = f"""<h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;font-weight:800;letter-spacing:-0.02em;color:{INK};">{escape(heading)}</h1>
<p style="margin:0 0 {"12px" if detail else "24px"};font-size:15px;line-height:1.6;color:{INK};">{escape(intro)}</p>
{detail_html}<table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td style="border-radius:12px;background:{BRAND};">
<a href="{href}" style="display:inline-block;padding:13px 24px;font-size:15px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:12px;">{escape(button_label)}</a>
</td></tr></table>"""
    if unsubscribe_url:
        unsub = escape(unsubscribe_url, quote=True)
        content += (
            f'\n<p style="margin:24px 0 0;padding-top:20px;border-top:1px solid {LINE};font-size:12px;line-height:1.6;color:{MUTED};">'
            f"You get this because “{escape(unsubscribe_label or '')}” emails are on. "
            f'<a href="{unsub}" style="color:{LINK};">Unsubscribe</a> or change them in '
            f'<a href="{escape(site_url, quote=True)}/settings/notifications" style="color:{LINK};">Settings → Notifications</a>.</p>'
        )
    text_lines = [heading, "", intro]
    if detail:
        text_lines += ["", detail]
    text_lines += ["", f"{button_label}: {link}"]
    if unsubscribe_url:
        text_lines += [
            "",
            f"Unsubscribe from “{unsubscribe_label}” emails: {unsubscribe_url}",
            f"Manage all emails: {site_url}/settings/notifications",
        ]
    text_lines += ["", "— SaveStream"]
    html = _shell(subject=subject, preheader=intro, content=content, site_url=site_url, footer_note="")
    return RenderedEmail(subject=subject, text="\n".join(text_lines) + "\n", html=html)


def notification_email(
    kind: str,
    *,
    handle: str,
    link: str,
    site_url: str,
    unsubscribe_url: str | None,
    unsubscribe_label: str | None,
    available_minutes: int | None = None,
) -> RenderedEmail | None:
    """The six notification emails users can turn off. None for kinds that
    have no email."""
    def make(
        *, subject: str, heading: str, intro: str, button_label: str, detail: str = ""
    ) -> RenderedEmail:
        return _notification_shell(
            subject=subject,
            heading=heading,
            intro=intro,
            button_label=button_label,
            detail=detail,
            link=link,
            site_url=site_url,
            unsubscribe_url=unsubscribe_url,
            unsubscribe_label=unsubscribe_label,
        )

    if kind == "creator_live":
        return make(
            subject=f"{handle} is LIVE now",
            heading=f"{handle} just went LIVE",
            intro="SaveStream noticed the channel is live. If auto-record is on, the recording has already started in the cloud.",
            button_label="Open channel",
        )
    if kind == "recording_ready":
        return make(
            subject=f"Your {handle} recording is ready",
            heading="Your recording is ready",
            intro=f"The LIVE from {handle} has been saved. You can watch it or download the MP4.",
            detail="Recordings are kept for a limited time; download a copy to keep it.",
            button_label="Watch recording",
        )
    if kind in ("recording_failed", "recording_missed"):
        missed = kind == "recording_missed"
        return make(
            subject=f"{handle} recording {'missed' if missed else 'didn’t complete'}",
            heading="Recording missed" if missed else "Recording didn’t complete",
            intro=(
                f"{handle} ended before a cloud recording slot became available."
                if missed
                else f"The recording of {handle} stopped before it finished. Anything saved is kept."
            ),
            detail="Open it to see what happened. Credits are only used for time that was recorded.",
            button_label="View details",
        )
    if kind == "recording_expiring":
        return make(
            subject=f"Your {handle} recording expires in about 24 hours",
            heading="A recording expires soon",
            intro=f"The {handle} recording will be deleted from cloud storage in about 24 hours.",
            detail="Download the MP4 now if you want to keep it.",
            button_label="Download recording",
        )
    if kind == "credits_low":
        minutes = max(available_minutes or 0, 0)
        return make(
            subject="Your SaveStream credits are running low",
            heading="Credits are running low",
            intro=f"You have {minutes} cloud recording minute{'s' if minutes != 1 else ''} left. Auto-record pauses when they run out.",
            button_label="Buy credits",
        )
    if kind == "cloud_minutes_exhausted":
        return make(
            subject="You’re out of SaveStream credits",
            heading="You’re out of credits",
            intro="Your cloud recording minutes have run out, so auto-record is paused. Channels are still checked for free.",
            detail="Buy credits to resume recording. Credits never expire.",
            button_label="Buy credits",
        )
    return None


def partner_email(kind: str, *, name: str, reference: str, site_url: str) -> RenderedEmail | None:
    """Replies to a Partner Program applicant (sent to the email they gave)."""
    first = name.strip().split(" ")[0] or "there"
    if kind == "partner_received":
        return _notification_shell(
            subject=f"We received your SaveStream partner application ({reference})",
            heading=f"Thanks, {first}! Application received",
            intro=f"We’ll review your channel and email you within {SUPPORT_RESPONSE_TIME}. Nothing is published until you approve the final quote, image and clip.",
            detail="Once your story is published, 50 free recording hours are added to your SaveStream account (same email). You can withdraw consent at any time by emailing privacy@savestream.online.",
            button_label="About the Partner Program",
            link=f"{site_url}/partners/apply",
            site_url=site_url,
            unsubscribe_url=None,
            unsubscribe_label=None,
        )
    if kind == "partner_approved":
        return _notification_shell(
            subject="Your SaveStream partner application was approved",
            heading=f"You’re in, {first}!",
            intro="Your Partner Program application was approved. We’ll send the final quote, image and clip for your sign-off before anything is published.",
            detail="When your story goes live, 50 free recording hours are added to the SaveStream account that uses this email. No account yet? Sign up with this email.",
            button_label="Open SaveStream",
            link=site_url,
            site_url=site_url,
            unsubscribe_url=None,
            unsubscribe_label=None,
        )
    return None
