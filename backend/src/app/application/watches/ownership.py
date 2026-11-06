"""Who may record a channel, and which client may see it.

Verified channels (bio code) record everywhere. On the web, a channel added
with the ownership attestation ("web_attested", or "web_attested_legacy" for
channels added before the box was required) may also record, once
``web_require_ownership`` is off. Those unverified web channels are web-only:
the Android app must never see them, their recordings or their
notifications, and can never start them.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.watches.verification import verification_required
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import ChannelOwnershipAttestation, Watch
from app.settings import AppSettings

WEB_BASES = frozenset({"web_attested", "web_attested_legacy"})
# The wording the user agreed to; bump when the checkbox text changes.
ATTESTATION_STATEMENT_VERSION = "2026-11-06"
ATTESTATION_STATEMENT = (
    "I own this channel or have the creator's permission to record it."
)


def is_web_only(watch: Watch) -> bool:
    """An unverified channel that may only exist on the web."""
    return watch.owner_verified_at is None and watch.ownership_basis in WEB_BASES


def visible_to(watch: Watch, principal: AuthPrincipal) -> bool:
    return not (principal.is_mobile and is_web_only(watch))


def may_record(
    watch: Watch,
    settings: AppSettings,
    *,
    client_type: str | None,
    now: datetime | None = None,
) -> bool:
    """Whether this channel may be recorded for a request from ``client_type``
    ("web", "mobile", or None for the server's own auto-record)."""
    if not verification_required(watch, settings, now):
        return True
    if client_type == "mobile":
        return False
    return watch.ownership_basis in WEB_BASES and not settings.web_require_ownership


def record_attestation(
    session: AsyncSession,
    watch: Watch,
    principal: AuthPrincipal,
    *,
    ip_address: str | None,
    user_agent: str | None,
) -> ChannelOwnershipAttestation:
    """Store the consent evidence for one tick of the ownership box; the
    caller commits."""
    row = ChannelOwnershipAttestation(
        watch_id=watch.id,
        user_id=principal.user_id,
        statement_version=ATTESTATION_STATEMENT_VERSION,
        client_type=principal.client_type,
        ip_address=(ip_address or None) and ip_address[:64],
        user_agent=(user_agent or None) and user_agent[:512],
    )
    session.add(row)
    return row


def watch_username(watch: Watch) -> str | None:
    name = watch.resolved_username or (
        watch.source_value if watch.source_type == "username" else None
    )
    return name.lstrip("@").casefold() if name else None


def recording_username(recording: Recording) -> str | None:
    name = recording.resolved_username or (
        recording.source_value if recording.source_type == "username" else None
    )
    return name.lstrip("@").casefold() if name else None


async def mobile_hidden_usernames(session: AsyncSession, user_id: uuid.UUID) -> set[str]:
    """Channels whose recordings and notifications the app must not show: the
    user's web-only channels (deleted ones too), unless the same channel is
    also one the app may see."""
    watches = (await session.scalars(select(Watch).where(Watch.user_id == user_id))).all()
    hidden: set[str] = set()
    shown: set[str] = set()
    for watch in watches:
        name = watch_username(watch)
        if name is None:
            continue
        if is_web_only(watch):
            hidden.add(name)
        elif watch.deleted_at is None:
            shown.add(name)
    return hidden - shown


async def mobile_hidden_watch_ids(session: AsyncSession, user_id: uuid.UUID) -> set[uuid.UUID]:
    watches = (await session.scalars(select(Watch).where(Watch.user_id == user_id))).all()
    return {watch.id for watch in watches if is_web_only(watch)}


async def mobile_hidden_resources(
    session: AsyncSession, user_id: uuid.UUID
) -> tuple[set[str], set[str]]:
    """(watch ids, recording ids) the app must not see, as notification
    resource ids."""
    watch_ids = {str(i) for i in await mobile_hidden_watch_ids(session, user_id)}
    hidden = await mobile_hidden_usernames(session, user_id)
    recording_ids: set[str] = set()
    if hidden:
        name = func.lower(
            func.ltrim(func.coalesce(Recording.resolved_username, Recording.source_value), "@")
        )
        rows = await session.scalars(
            select(Recording.id).where(Recording.user_id == user_id, name.in_(hidden))
        )
        recording_ids = {str(i) for i in rows.all()}
    return watch_ids, recording_ids


async def notification_hidden_from_app(
    session: AsyncSession, notification: UserNotification
) -> bool:
    """A notification about a web-only channel or its recordings: no push to
    phones, and the app's notification list leaves it out."""
    if notification.resource_type not in {"watch", "recording"} or not notification.resource_id:
        return False
    watch_ids, recording_ids = await mobile_hidden_resources(session, notification.user_id)
    if notification.resource_type == "watch":
        return notification.resource_id in watch_ids
    return notification.resource_id in recording_ids
