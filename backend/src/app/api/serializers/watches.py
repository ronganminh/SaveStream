from typing import cast

from app.api.schemas.recordings import Creator, Source
from app.api.schemas.watches import LiveStatusValue, WatchResponse, WatchStatusValue
from app.infrastructure.db.watch_models import Watch


def watch_response(watch: Watch) -> WatchResponse:
    creator = None
    if watch.resolved_username:
        creator = Creator(
            username=watch.resolved_username,
            display_name=watch.resolved_username,
            avatar_url=None,
        )
    return WatchResponse(
        id=str(watch.id),
        source=Source.model_validate(
            {"type": watch.source_type, "value": watch.source_value}
        ),
        creator=creator,
        status=cast(WatchStatusValue, watch.status),
        live_status=cast(LiveStatusValue, watch.live_status),
        auto_record=watch.auto_record,
        last_checked_at=watch.last_checked_at,
        next_check_at=watch.next_check_at,
        last_live_at=watch.last_live_at,
        created_at=watch.created_at,
        updated_at=watch.updated_at,
    )
