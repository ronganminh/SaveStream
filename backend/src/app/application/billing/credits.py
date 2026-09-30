from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.credit_models import (
    CreditAccount,
    CreditLedgerEntry,
    CreditReservation,
)


class BillingCreditService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def _account(
        self,
        user_id: uuid.UUID,
        *,
        lock: bool = True,
    ) -> CreditAccount:
        statement = select(CreditAccount).where(
            CreditAccount.user_id == user_id
        )
        if lock:
            statement = statement.with_for_update()
        account = await self.session.scalar(statement)
        if account is None:
            account = CreditAccount(user_id=user_id, posted_balance=0)
            self.session.add(account)
            await self.session.flush()
        return account

    async def _reserved(self, account_id: uuid.UUID) -> int:
        rows = list(
            (
                await self.session.scalars(
                    select(CreditReservation).where(
                        CreditReservation.account_id == account_id,
                        CreditReservation.status == "active",
                    )
                )
            ).all()
        )
        return sum(
            item.reserved - item.settled - item.released
            for item in rows
        )

    async def grant_purchase(
        self,
        *,
        user_id: uuid.UUID,
        payment_order_id: uuid.UUID,
        credits: int,
    ) -> CreditLedgerEntry:
        reference_key = f"payment:{payment_order_id}:grant"
        existing = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == reference_key
            )
        )
        if existing is not None:
            return existing

        account = await self._account(user_id)
        account.posted_balance += credits
        entry = CreditLedgerEntry(
            account_id=account.id,
            user_id=user_id,
            entry_type="grant",
            amount=credits,
            balance_after=account.posted_balance,
            reference_type="payment_order",
            reference_id=str(payment_order_id),
            reference_key=reference_key,
            details={"source": "verified_payment"},
        )
        self.session.add(entry)
        await self.session.flush()
        return entry

    async def hold_refund(
        self,
        *,
        user_id: uuid.UUID,
        refund_id: uuid.UUID,
        credits: int,
    ) -> CreditLedgerEntry:
        reference_key = f"refund:{refund_id}:debit"
        existing = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == reference_key
            )
        )
        if existing is not None:
            return existing

        account = await self._account(user_id)
        reserved = await self._reserved(account.id)
        new_balance = account.posted_balance - credits
        if new_balance < reserved or new_balance < 0:
            raise ApplicationError(
                "INSUFFICIENT_CREDITS",
                "Available credit is insufficient for this refund",
                status_code=409,
                details={
                    "posted": account.posted_balance,
                    "reserved": reserved,
                    "refund_credits": credits,
                },
            )
        account.posted_balance = new_balance
        entry = CreditLedgerEntry(
            account_id=account.id,
            user_id=user_id,
            entry_type="refund",
            amount=-credits,
            balance_after=new_balance,
            reference_type="refund",
            reference_id=str(refund_id),
            reference_key=reference_key,
            details={"state": "held_for_provider_refund"},
        )
        self.session.add(entry)
        await self.session.flush()
        return entry

    async def compensate_failed_refund(
        self,
        *,
        user_id: uuid.UUID,
        refund_id: uuid.UUID,
        credits: int,
    ) -> CreditLedgerEntry:
        reference_key = f"refund:{refund_id}:compensation"
        existing = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key == reference_key
            )
        )
        if existing is not None:
            return existing

        hold = await self.session.scalar(
            select(CreditLedgerEntry).where(
                CreditLedgerEntry.reference_key
                == f"refund:{refund_id}:debit"
            )
        )
        if hold is None:
            raise ApplicationError(
                "INTERNAL_ERROR",
                "Refund credit hold is missing",
                status_code=500,
            )

        account = await self._account(user_id)
        account.posted_balance += credits
        entry = CreditLedgerEntry(
            account_id=account.id,
            user_id=user_id,
            entry_type="grant",
            amount=credits,
            balance_after=account.posted_balance,
            reference_type="refund_compensation",
            reference_id=str(refund_id),
            reference_key=reference_key,
            details={"reason": "provider_refund_failed"},
        )
        self.session.add(entry)
        await self.session.flush()
        return entry
