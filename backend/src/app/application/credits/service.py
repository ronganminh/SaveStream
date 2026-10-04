from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.pricing.policy import PricingEvaluator
from app.application.pricing.service import PricingService
from app.domain.common.errors import ApplicationError
from app.domain.credits.types import CreditBalance, ReservationStatus
from app.infrastructure.db.credit_models import (
    CreditAccount,
    CreditLedgerEntry,
    CreditReservation,
    PricingSnapshot,
)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    payload = json.dumps(
        {"created_at": aware(created_at).isoformat(), "id": str(row_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


@dataclass(frozen=True, slots=True)
class CreditPage:
    items: list[CreditLedgerEntry]
    next_cursor: str | None
    has_more: bool


@dataclass(frozen=True, slots=True)
class CreditReservationPage:
    items: list[CreditReservation]
    next_cursor: str | None
    has_more: bool


@dataclass(frozen=True, slots=True)
class ReconciliationResult:
    user_id: uuid.UUID
    account_balance: int
    ledger_balance: int
    reserved: int
    available: int
    consistent: bool


class CreditService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def _account(self, user_id: uuid.UUID, *, lock: bool = False) -> CreditAccount | None:
        statement = select(CreditAccount).where(CreditAccount.user_id == user_id)
        if lock:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)

    async def _active_reserved(self, account_id: uuid.UUID) -> int:
        value = await self.session.scalar(
            select(
                func.coalesce(
                    func.sum(
                        CreditReservation.reserved
                        - CreditReservation.settled
                        - CreditReservation.released
                    ),
                    0,
                )
            ).where(
                CreditReservation.account_id == account_id,
                CreditReservation.status == ReservationStatus.ACTIVE.value,
            )
        )
        return int(value or 0)

    async def balance(self, user_id: uuid.UUID) -> CreditBalance:
        account = await self._account(user_id)
        if account is None:
            return CreditBalance(posted=0, reserved=0, available=0)
        reserved = await self._active_reserved(account.id)
        return CreditBalance(
            posted=account.posted_balance,
            reserved=reserved,
            available=account.posted_balance - reserved,
        )

    async def reserve_recording(
        self,
        *,
        user_id: uuid.UUID,
        recording_id: uuid.UUID,
        max_duration_seconds: int,
    ) -> tuple[CreditReservation, int]:
        existing = await self.session.scalar(
            select(CreditReservation).where(
                CreditReservation.recording_id == recording_id
            )
        )
        if existing is not None:
            return existing, existing.reserved

        rule = await PricingService(self.session).active_rule()
        snapshot = await PricingService(self.session).snapshot(rule)
        max_cost = PricingService.estimate_max(snapshot, max_duration_seconds)

        account = await self._account(user_id, lock=True)
        posted = account.posted_balance if account is not None else 0
        reserved = await self._active_reserved(account.id) if account is not None else 0
        available = posted - reserved
        if max_cost > available:
            raise ApplicationError(
                "INSUFFICIENT_CREDITS",
                "Available credit is insufficient",
                status_code=402,
                retryable=False,
                details={"required": max_cost, "available": available},
            )
        if account is None:
            # max_cost can only be zero here; keep a real account for consistent reads.
            account = CreditAccount(user_id=user_id, posted_balance=0)
            self.session.add(account)
            await self.session.flush()

        reservation = CreditReservation(
            account_id=account.id,
            user_id=user_id,
            recording_id=recording_id,
            pricing_snapshot_id=snapshot.id,
            reserved=max_cost,
            settled=0,
            released=0,
            status=ReservationStatus.ACTIVE.value,
        )
        self.session.add(reservation)
        await self.session.flush()
        return reservation, max_cost

    async def can_afford(
        self,
        *,
        user_id: uuid.UUID,
        max_duration_seconds: int,
    ) -> tuple[bool, int, int]:
        rule = await PricingService(self.session).active_rule()
        snapshot = await PricingService(self.session).snapshot(rule)
        # Recordings are capped to what the balance covers, so being able to pay
        # for the smallest billable unit is enough to start.
        probe_seconds = max_duration_seconds
        if snapshot.policy_type == "duration_units_v1":
            probe_seconds = min(max_duration_seconds, int(snapshot.policy["unit_seconds"]))
        required = PricingService.estimate_max(snapshot, probe_seconds)
        # The probe snapshot is not part of a recording and must not persist.
        await self.session.delete(snapshot)
        await self.session.flush()
        balance = await self.balance(user_id)
        return balance.available >= required, required, balance.available

    async def affordable_duration_seconds(
        self,
        *,
        user_id: uuid.UUID,
        max_duration_seconds: int,
    ) -> int:
        """Longest recording (up to max_duration_seconds) the available balance pays for.

        Returns 0 when not even the smallest billable unit is affordable.
        """
        rule = await PricingService(self.session).active_rule()
        available = (await self.balance(user_id)).available
        policy = dict(rule.policy)
        if rule.policy_type == "duration_units_v1":
            unit_seconds = int(policy["unit_seconds"])
            credits_per_unit = int(policy["credits_per_unit"])
            minimum_credits = int(policy.get("minimum_credits", 0))
            if credits_per_unit == 0:
                return max_duration_seconds if available >= minimum_credits else 0
            if available < max(minimum_credits, credits_per_unit):
                return 0
            units = available // credits_per_unit
            return min(max_duration_seconds, units * unit_seconds)
        full_cost = PricingEvaluator.cost(
            policy_type=rule.policy_type,
            policy=policy,
            duration_seconds=max_duration_seconds,
            bytes_recorded=0,
        )
        return max_duration_seconds if available >= full_cost else 0

    async def settle_recording(
        self,
        *,
        recording_id: uuid.UUID,
        duration_seconds: int,
        bytes_recorded: int,
    ) -> int:
        reservation = await self.session.scalar(
            select(CreditReservation)
            .where(CreditReservation.recording_id == recording_id)
            .with_for_update()
        )
        if reservation is None:
            raise ApplicationError(
                "INTERNAL_ERROR",
                "Credit reservation is missing for recording",
                status_code=500,
            )
        if reservation.status == ReservationStatus.SETTLED.value:
            return reservation.settled
        if reservation.status == ReservationStatus.RELEASED.value:
            if duration_seconds == 0 and bytes_recorded == 0:
                return 0
            raise ApplicationError(
                "INTERNAL_ERROR",
                "Released credit reservation cannot be settled",
                status_code=500,
            )

        snapshot = await self.session.get(PricingSnapshot, reservation.pricing_snapshot_id)
        if snapshot is None:
            raise ApplicationError(
                "INTERNAL_ERROR", "Pricing snapshot is missing", status_code=500
            )
        actual = PricingService.actual_cost(
            snapshot,
            duration_seconds=duration_seconds,
            bytes_recorded=bytes_recorded,
        )
        if actual > reservation.reserved:
            raise ApplicationError(
                "INTERNAL_ERROR",
                "Actual credit cost exceeds reserved maximum",
                status_code=500,
                details={"actual": actual, "reserved": reservation.reserved},
            )

        account = await self.session.scalar(
            select(CreditAccount)
            .where(CreditAccount.id == reservation.account_id)
            .with_for_update()
        )
        if account is None:
            raise ApplicationError(
                "INTERNAL_ERROR", "Credit account is missing", status_code=500
            )

        charge_key = f"recording:{recording_id}:charge"
        existing_charge = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == charge_key
            )
        )
        if existing_charge is None and actual > 0:
            if account.posted_balance < actual:
                raise ApplicationError(
                    "INTERNAL_ERROR",
                    "Reserved credit is no longer available",
                    status_code=500,
                )
            account.posted_balance -= actual
            self.session.add(
                CreditLedgerEntry(
                    account_id=account.id,
                    user_id=reservation.user_id,
                    entry_type="charge",
                    amount=-actual,
                    balance_after=account.posted_balance,
                    reference_type="recording",
                    reference_id=str(recording_id),
                    reference_key=charge_key,
                    details={"pricing_snapshot_id": str(snapshot.id)},
                )
            )

        released = reservation.reserved - actual
        if released > 0:
            release_key = f"recording:{recording_id}:release"
            existing_release = await self.session.scalar(
                select(CreditLedgerEntry).where(
                    CreditLedgerEntry.reference_key == release_key
                )
            )
            if existing_release is None:
                self.session.add(
                    CreditLedgerEntry(
                        account_id=account.id,
                        user_id=reservation.user_id,
                        entry_type="release",
                        amount=0,
                        balance_after=account.posted_balance,
                        reference_type="recording",
                        reference_id=str(recording_id),
                        reference_key=release_key,
                        details={"released_reservation": released},
                    )
                )

        reservation.settled = actual
        reservation.released = released
        reservation.status = (
            ReservationStatus.SETTLED.value
            if actual > 0
            else ReservationStatus.RELEASED.value
        )
        await self.session.flush()
        return actual

    async def release_recording(
        self,
        *,
        recording_id: uuid.UUID,
        reason: str,
    ) -> int:
        reservation = await self.session.scalar(
            select(CreditReservation)
            .where(CreditReservation.recording_id == recording_id)
            .with_for_update()
        )
        if reservation is None:
            return 0
        if reservation.status != ReservationStatus.ACTIVE.value:
            return reservation.released

        account = await self.session.scalar(
            select(CreditAccount)
            .where(CreditAccount.id == reservation.account_id)
            .with_for_update()
        )
        if account is None:
            raise ApplicationError(
                "INTERNAL_ERROR", "Credit account is missing", status_code=500
            )
        amount = reservation.reserved - reservation.settled - reservation.released
        release_key = f"recording:{recording_id}:release"
        existing = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == release_key
            )
        )
        if existing is None and amount > 0:
            self.session.add(
                CreditLedgerEntry(
                    account_id=account.id,
                    user_id=reservation.user_id,
                    entry_type="release",
                    amount=0,
                    balance_after=account.posted_balance,
                    reference_type="recording",
                    reference_id=str(recording_id),
                    reference_key=release_key,
                    details={"released_reservation": amount, "reason": reason},
                )
            )
        reservation.released += amount
        reservation.status = ReservationStatus.RELEASED.value
        await self.session.flush()
        return amount

    async def transactions(
        self,
        user_id: uuid.UUID,
        *,
        limit: int,
        cursor: str | None,
    ) -> CreditPage:
        statement = select(CreditLedgerEntry).where(
            CreditLedgerEntry.user_id == user_id
        )
        if cursor:
            created_at, row_id = decode_cursor(cursor)
            statement = statement.where(
                or_(
                    CreditLedgerEntry.created_at < created_at,
                    and_(
                        CreditLedgerEntry.created_at == created_at,
                        CreditLedgerEntry.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        CreditLedgerEntry.created_at.desc(),
                        CreditLedgerEntry.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = (
            encode_cursor(items[-1].created_at, items[-1].id)
            if has_more and items
            else None
        )
        return CreditPage(items, next_cursor, has_more)

    async def reservations(
        self,
        user_id: uuid.UUID,
        *,
        limit: int,
        cursor: str | None,
    ) -> CreditReservationPage:
        statement = select(CreditReservation).where(
            CreditReservation.user_id == user_id
        )
        if cursor:
            created_at, row_id = decode_cursor(cursor)
            statement = statement.where(
                or_(
                    CreditReservation.created_at < created_at,
                    and_(
                        CreditReservation.created_at == created_at,
                        CreditReservation.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        CreditReservation.created_at.desc(),
                        CreditReservation.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = (
            encode_cursor(items[-1].created_at, items[-1].id)
            if has_more and items
            else None
        )
        return CreditReservationPage(items, next_cursor, has_more)


    async def grant_signup_credits(
        self,
        user_id: uuid.UUID,
        amount: int,
    ) -> CreditLedgerEntry | None:
        """Grant the one-time free trial credits; at most once per user.

        Flushes without committing so the grant lands in the caller's transaction.
        """
        if amount <= 0:
            return None
        reference_key = f"signup-bonus:{user_id}"
        existing = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == reference_key
            )
        )
        if existing is not None:
            return existing

        account = await self._account(user_id, lock=True)
        if account is None:
            account = CreditAccount(user_id=user_id, posted_balance=0)
            self.session.add(account)
            await self.session.flush()
        account.posted_balance += amount
        entry = CreditLedgerEntry(
            account_id=account.id,
            user_id=user_id,
            entry_type="grant",
            amount=amount,
            balance_after=account.posted_balance,
            reference_type="signup_bonus",
            reference_id=str(user_id),
            reference_key=reference_key,
            details={"reason": "free trial credits"},
        )
        self.session.add(entry)
        await self.session.flush()
        return entry


class CreditAdminService:
    """Internal/admin adjustment service with idempotent references."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def adjust(
        self,
        *,
        user_id: uuid.UUID,
        amount: int,
        idempotency_key: str,
        reason: str,
        counts_as_purchase: bool = False,
        commit: bool = True,
    ) -> CreditLedgerEntry:
        try:
            uuid.UUID(idempotency_key)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Adjustment idempotency key must be a UUID",
                status_code=400,
            ) from exc

        if counts_as_purchase and amount <= 0:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Only positive manual grants can count as a purchase",
                status_code=400,
            )

        reference_key = f"admin-adjustment:{idempotency_key}"
        existing = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == reference_key
            )
        )
        if existing is not None:
            if (
                existing.user_id != user_id
                or existing.amount != amount
                or existing.details.get("reason") != reason
                or bool(existing.details.get("counts_as_purchase", False))
                != counts_as_purchase
            ):
                raise ApplicationError(
                    "IDEMPOTENCY_KEY_REUSED",
                    "Adjustment idempotency key was already used with a different request",
                    status_code=409,
                )
            return existing

        account = await self.session.scalar(
            select(CreditAccount)
            .where(CreditAccount.user_id == user_id)
            .with_for_update()
        )
        if account is None:
            account = CreditAccount(user_id=user_id, posted_balance=0)
            self.session.add(account)
            await self.session.flush()

        active_reserved = await CreditService(self.session)._active_reserved(account.id)
        new_balance = account.posted_balance + amount
        if new_balance < active_reserved or new_balance < 0:
            raise ApplicationError(
                "INSUFFICIENT_CREDITS",
                "Adjustment would make available credit negative",
                status_code=409,
                details={
                    "posted": account.posted_balance,
                    "reserved": active_reserved,
                    "adjustment": amount,
                },
            )
        account.posted_balance = new_balance
        entry = CreditLedgerEntry(
            account_id=account.id,
            user_id=user_id,
            entry_type="adjustment",
            amount=amount,
            balance_after=new_balance,
            reference_type="admin_adjustment",
            reference_id=idempotency_key,
            reference_key=reference_key,
            details={
                "reason": reason,
                "counts_as_purchase": counts_as_purchase,
            },
        )
        self.session.add(entry)
        if commit:
            await self.session.commit()
            await self.session.refresh(entry)
        else:
            await self.session.flush()
        return entry


class CreditReconciliationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def reconcile_account(self, user_id: uuid.UUID) -> ReconciliationResult:
        account = await self.session.scalar(
            select(CreditAccount).where(CreditAccount.user_id == user_id)
        )
        if account is None:
            return ReconciliationResult(user_id, 0, 0, 0, 0, True)

        last_entry = await self.session.scalar(
            select(CreditLedgerEntry)
            .where(CreditLedgerEntry.account_id == account.id)
            .order_by(CreditLedgerEntry.created_at.desc(), CreditLedgerEntry.id.desc())
            .limit(1)
        )
        ledger_balance = last_entry.balance_after if last_entry is not None else 0
        reserved = await CreditService(self.session)._active_reserved(account.id)
        available = account.posted_balance - reserved
        consistent = (
            account.posted_balance == ledger_balance
            and account.posted_balance >= 0
            and available >= 0
        )
        return ReconciliationResult(
            user_id=user_id,
            account_balance=account.posted_balance,
            ledger_balance=ledger_balance,
            reserved=reserved,
            available=available,
            consistent=consistent,
        )
