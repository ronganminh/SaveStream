from typing import cast

from app.api.schemas.recordings import Creator, Source
from app.api.schemas.watches import (
    AutoRecordStateValue,
    LiveStatusValue,
    WatchResponse,
    WatchStatusValue,
)
from app.infrastructure.db.watch_models import Watch


def watch_response(
    watch: Watch,
    *,
    is_pro: bool | None = None,
    has_purchased: bool | None = None,
    waiting_for_cloud_slot: bool = False,
) -> WatchResponse:
    creator = None
    if watch.resolved_username:
        creator = Creator(
            username=watch.resolved_username,
            display_name=watch.creator_display_name or watch.resolved_username,
            avatar_url=watch.creator_avatar_url,
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
        notify_on_live=watch.notify_on_live,
        last_checked_at=watch.last_checked_at,
        next_check_at=watch.next_check_at,
        last_live_at=watch.last_live_at,
        created_at=watch.created_at,
        updated_at=watch.updated_at,
    )
