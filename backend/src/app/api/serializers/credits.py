from app.api.schemas.credits import (
    CreditReservationResponse,
    CreditTransactionResponse,
)
from app.application.credits.service import (
    PAYMENT_ORDER_REFERENCE_TYPES,
    LedgerContext,
)
from app.infrastructure.db.credit_models import CreditLedgerEntry, CreditReservation


def _released_credits(entry: CreditLedgerEntry) -> int | None:
    if entry.entry_type != "release":
        return None
    value = (entry.details or {}).get("released_reservation")
    return value if isinstance(value, int) and value >= 0 else None


def transaction_response(
    entry: CreditLedgerEntry, context: LedgerContext | None = None
) -> CreditTransactionResponse:
    order = recording = None
    if context is not None and entry.reference_id:
        if entry.reference_type in PAYMENT_ORDER_REFERENCE_TYPES:
            order = context.orders.get(entry.reference_id)
        elif entry.reference_type == "recording":
            recording = context.recordings.get(entry.reference_id)
    return CreditTransactionResponse.model_validate(
        {
            "id": str(entry.id),
            "type": entry.entry_type,
            "amount": entry.amount,
            "balance_after": entry.balance_after,
            "reference_type": entry.reference_type,
            "reference_id": entry.reference_id,
            "released_credits": _released_credits(entry),
            "store_order_id": order.store_order_id if order else None,
            "package_name": order.package_name if order else None,
            "recording_channel_username": (
                recording.channel_username if recording else None
            ),
            "recording_duration_seconds": (
                recording.duration_seconds if recording else None
            ),
            "created_at": entry.created_at,
        }
    )


def reservation_response(
    reservation: CreditReservation,
) -> CreditReservationResponse:
    return CreditReservationResponse.model_validate(
        {
            "id": str(reservation.id),
            "recording_id": str(reservation.recording_id),
            "reserved": reservation.reserved,
            "settled": reservation.settled,
            "released": reservation.released,
            "status": reservation.status,
            "created_at": reservation.created_at,
        }
    )
