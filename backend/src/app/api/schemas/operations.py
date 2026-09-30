from pydantic import BaseModel, ConfigDict


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class OperationalSnapshotResponse(StrictModel):
    active_recordings: int
    failed_recordings_recent: int
    pending_outbox_events: int
    unprocessed_payment_events: int
    pending_payment_orders: int
    paused_error_watches: int
