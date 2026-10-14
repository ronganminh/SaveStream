import time
from typing import cast
from urllib.parse import parse_qs, urlparse

from app.api.schemas.recordings import Creator, Source
from app.api.schemas.watches import (
    AutoRecordStateValue,
    LiveStatusValue,
    WatchResponse,
    WatchStatusValue,
)
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch


def creator_avatar_url(watch: Watch) -> str | None:
    """Stable cached copy when available, else the raw TikTok URL while it is
    still valid (it is signed and expires; an expired one only fails to load)."""
    if watch.creator_avatar_cached_url:
        return watch.creator_avatar_cached_url
    if watch.creator_avatar_url and not tiktok_url_expired(watch.creator_avatar_url):
        return watch.creator_avatar_url
    return None


def tiktok_url_expired(url: str, *, now: float | None = None) -> bool:
    """TikTok CDN URLs carry their expiry as `x-expires` (unix seconds)."""
    values = parse_qs(urlparse(url).query).get("x-expires")
    if not values:
        return False
    try:
        return int(values[0]) <= (now if now is not None else time.time())
    except ValueError:
        return False


def active_recording_for(
    watch: Watch,
    recordings: list[Recording],
) -> Recording | None:
    """Match an in-flight Recording to a Watch by room id or creator handle."""
    room_id = watch.resolved_room_id
    username = (watch.resolved_username or "").lower() or None
    for recording in recordings:
        if room_id and (
            recording.room_id == room_id
            or (recording.source_type == "room_id" and recording.source_value == room_id)
        ):
            return recording
        if username and (recording.resolved_username or "").lower() == username:
            return recording
    return None


def watch_response(
    watch: Watch,
    *,
    is_pro: bool | None = None,
    has_purchased: bool | None = None,
    waiting_for_cloud_slot: bool = False,
    active_recording: Recording | None = None,
) -> WatchResponse:
    creator = None
    if watch.resolved_username:
        creator = Creator(
            username=watch.resolved_username,
            display_name=watch.creator_display_name or watch.resolved_username,
            avatar_url=creator_avatar_url(watch),
        )
    if not watch.auto_record:
        auto_record_state: AutoRecordStateValue = "off"
    elif watch.status == "paused_insufficient_credit" and has_purchased is not False:
        auto_record_state = "paused_no_cloud_minutes"
    elif is_pro is False:
        auto_record_state = "off"
    elif waiting_for_cloud_slot:
        auto_record_state = "waiting_for_cloud_slot"
    elif watch.status == "active":
        auto_record_state = "active"
    else:
        auto_record_state = "off"

    return WatchResponse(
        id=str(watch.id),
        source=Source.model_validate(
            {"type": watch.source_type, "value": watch.source_value}
        ),
        creator=creator,
        status=cast(WatchStatusValue, watch.status),
        live_status=cast(LiveStatusValue, watch.live_status),
        auto_record=watch.auto_record,
        auto_record_state=auto_record_state,
        active_recording_id=(
            str(active_recording.id) if active_recording is not None else None
        ),
        active_recording_status=(
            active_recording.status if active_recording is not None else None
        ),
        notify_on_live=watch.notify_on_live,
        last_checked_at=watch.last_checked_at,
        next_check_at=watch.next_check_at,
        last_live_at=watch.last_live_at,
        created_at=watch.created_at,
        updated_at=watch.updated_at,
    )
