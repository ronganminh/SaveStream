from app.api.schemas.credits import (
    CreditReservationResponse,
    CreditTransactionResponse,
)
from app.infrastructure.db.credit_models import CreditLedgerEntry, CreditReservation


def transaction_response(entry: CreditLedgerEntry) -> CreditTransactionResponse:
    return CreditTransactionResponse.model_validate(
        {
            "id": str(entry.id),
            "type": entry.entry_type,
            "amount": entry.amount,
            "balance_after": entry.balance_after,
            "reference_type": entry.reference_type,
            "reference_id": entry.reference_id,
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
