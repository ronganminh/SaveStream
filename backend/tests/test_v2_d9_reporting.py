from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.application.admin.overview_d9 import AdminOverviewService
from app.infrastructure.db.admin_models import AdminSupportReport
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.models import AuthSession, Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database


def test_d9_rollup_revenue_usage_and_retention(tmp_path) -> None:
    async def run() -> None:
        database = Database(
            f"sqlite+aiosqlite:///{tmp_path / 'd9-reporting.db'}"
        )
        now = datetime.now(timezone.utc)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                paid_user_id = uuid.uuid4()
                free_user_id = uuid.uuid4()
                account_id = uuid.uuid4()
                package_id = uuid.uuid4()
                order_id = uuid.uuid4()
                completed_recording_id = uuid.uuid4()

                session.add_all(
                    [
                        User(
                            id=paid_user_id,
                            email="paid@example.com",
                            normalized_email="paid@example.com",
                            role="user",
                            created_at=now - timedelta(hours=2),
                            updated_at=now - timedelta(hours=2),
                        ),
                        User(
                            id=free_user_id,
                            email="free@example.com",
                            normalized_email="free@example.com",
                            role="user",
                            created_at=now - timedelta(hours=1),
                            updated_at=now - timedelta(hours=1),
                        ),
                        AuthSession(
                            id=uuid.uuid4(),
                            user_id=paid_user_id,
                            token_family_id=uuid.uuid4(),
                            client_type="mobile",
                            refresh_token_hash="d9-refresh",
                            user_agent="test",
                            ip_address="203.0.113.5",
                            created_at=now - timedelta(hours=1),
                            last_seen_at=now - timedelta(minutes=5),
                            expires_at=now + timedelta(days=30),
                        ),
                        CreditPackage(
                            id=package_id,
                            code="d9-test",
                            name="D9 Test",
                            credits=100,
                            amount_minor=1000,
                            currency="USD",
                            active=True,
                        ),
                        PaymentOrder(
                            id=order_id,
                            user_id=paid_user_id,
                            package_id=package_id,
                            status="paid",
                            credits=100,
                            amount_minor=1000,
                            currency="USD",
                            provider="app_store",
                            provider_reference="d9-order",
                            paid_at=now - timedelta(minutes=40),
                            created_at=now - timedelta(minutes=45),
                            updated_at=now - timedelta(minutes=40),
                        ),
                        CreditAccount(
                            id=account_id,
                            user_id=paid_user_id,
                            posted_balance=40,
                        ),
                        CreditLedgerEntry(
                            id=uuid.uuid4(),
                            account_id=account_id,
                            user_id=paid_user_id,
                            entry_type="grant",
                            amount=100,
                            balance_after=100,
                            reference_type="payment_order",
                            reference_id=str(order_id),
                            reference_key="d9:payment:grant",
                            details={},
                            created_at=now - timedelta(minutes=40),
                        ),
                        CreditLedgerEntry(
                            id=uuid.uuid4(),
                            account_id=account_id,
                            user_id=paid_user_id,
                            entry_type="charge",
                            amount=-60,
                            balance_after=40,
                            reference_type="recording",
                            reference_id=str(completed_recording_id),
                            reference_key="d9:recording:charge",
                            details={},
                            created_at=now - timedelta(minutes=20),
                        ),
                        Recording(
                            id=completed_recording_id,
                            user_id=paid_user_id,
                            source_type="username",
                            source_value="paid_creator",
                            status="completed",
                            duration_seconds=3600,
                            bytes_recorded=1000,
                            estimated_max_cost=60,
                            actual_cost=60,
                            created_at=now - timedelta(minutes=50),
                            updated_at=now - timedelta(minutes=20),
                            ended_at=now - timedelta(minutes=20),
                        ),
                        Recording(
                            id=uuid.uuid4(),
                            user_id=paid_user_id,
                            source_type="username",
                            source_value="failed_creator",
                            status="failed",
                            duration_seconds=0,
                            bytes_recorded=0,
                            estimated_max_cost=0,
                            actual_cost=0,
                            error_code="D9_TEST",
                            created_at=now - timedelta(minutes=30),
                            updated_at=now - timedelta(minutes=25),
                            ended_at=now - timedelta(minutes=25),
                        ),
                        Recording(
                            id=uuid.uuid4(),
                            user_id=free_user_id,
                            source_type="username",
                            source_value="live_creator",
                            status="recording",
                            duration_seconds=0,
                            bytes_recorded=0,
                            estimated_max_cost=0,
                            created_at=now - timedelta(minutes=10),
                            updated_at=now - timedelta(minutes=5),
                            started_at=now - timedelta(minutes=10),
                        ),
                        AdminSupportReport(
                            id=uuid.uuid4(),
                            user_id=paid_user_id,
                            description="Expired report",
                            diagnostic_log={"error": "old"},
                            status="new",
                            expires_at=now - timedelta(seconds=1),
                            created_at=now - timedelta(days=181),
                            updated_at=now - timedelta(days=181),
                        ),
                    ]
                )
                await session.commit()

                service = AdminOverviewService(session)
                row = await service.compute_daily(day=now.date())

                assert row.new_users == 2
                assert row.active_users_daily == 1
                assert row.active_users_weekly == 1
                assert row.active_users_monthly == 1
                assert row.pro_users == 1
                assert row.free_users == 1
                assert row.free_to_pro_weekly == 1

                assert row.revenue_web_usd_minor == 0
                assert row.revenue_app_store_usd_minor == 1000
                assert row.revenue_google_play_usd_minor == 0
                assert row.estimated_store_fee_app_store_usd_minor == 300
                assert row.estimated_store_fee_google_play_usd_minor == 0

                assert row.cloud_minutes_used == 60
                assert row.recording_running == 1
                assert row.recording_errors_24h == 1
                assert row.recording_total_24h == 3
                assert row.recording_status_counts["completed"] == 1
                assert row.recording_status_counts["failed"] == 1
                assert row.recording_status_counts["recording"] == 1

                totals = await service.month_totals(day=now.date())
                assert totals == {
                    "web": 0,
                    "app_store": 1000,
                    "google_play": 0,
                    "store_fee": 300,
                }

                assert await service.purge_expired_support_reports() == 1
                await session.commit()
                assert (
                    await session.scalar(
                        select(AdminSupportReport).where(
                            AdminSupportReport.description == "Expired report"
                        )
                    )
                    is None
                )
        finally:
            await database.close()

    asyncio.run(run())
