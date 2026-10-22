"""reward_intents retention: rows (install device id, AdMob transaction id)
older than SAVESTREAM_REWARD_RETENTION_DAYS are deleted in batches by the
daily savestream.rewards.retention job; the credit ledger grants stay."""

from __future__ import annotations

from dataclasses import fields
from datetime import timedelta

import pytest
from sqlalchemy import func, select, update

from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.application.rewards.retention import prune_reward_intents
from app.application.rewards.service import RewardService
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.local_recording_models import RewardIntent
from app.infrastructure.queue.celery_app import celery_app
from app.settings import AppSettings
from tests.test_rewarded_cloud_minutes import _run, _settings, _user, _watch_ad


def test_old_reward_intents_are_deleted_and_ledger_kept(tmp_path) -> None:
    settings = _settings(
        tmp_path,
        "retention.db",
        reward_cloud_daily_cap=10,
        reward_cloud_device_daily_cap=10,
    )

    async def body(session) -> None:
        user = await _user(session, "retention@example.com")
        service = RewardService(session, settings)
        rewards = [await _watch_ad(service, user, f"txn-{index}") for index in range(5)]
        assert all(reward.status == "valid" for reward in rewards)
        assert (await CreditService(session).balance(user.id)).posted == 25

        now = utcnow()
        old_ids = [reward.id for reward in rewards[:3]]
        recent_ids = [reward.id for reward in rewards[3:]]
        # Three intents from more than a year ago, one just inside the window.
        await session.execute(
            update(RewardIntent)
            .where(RewardIntent.id.in_(old_ids))
            .values(created_at=now - timedelta(days=400))
        )
        await session.execute(
            update(RewardIntent)
            .where(RewardIntent.id == recent_ids[0])
            .values(created_at=now - timedelta(days=364))
        )
        await session.commit()

        deleted = await prune_reward_intents(
            session, retention_days=365, batch_size=2, now=now
        )
        assert deleted == 3

        remaining = set((await session.scalars(select(RewardIntent.id))).all())
        assert remaining == set(recent_ids)

        grants = (
            await session.scalars(
                select(CreditLedgerEntry).where(CreditLedgerEntry.reference_type == "reward")
            )
        ).all()
        assert len(grants) == 5
        assert {grant.reference_id for grant in grants} == {
            str(reward_id) for reward_id in old_ids + recent_ids
        }
        assert (await CreditService(session).balance(user.id)).posted == 25

        # Nothing left to delete: a second run is a no-op.
        assert await prune_reward_intents(
            session, retention_days=365, batch_size=2, now=now
        ) == 0
        assert int(
            await session.scalar(select(func.count()).select_from(RewardIntent)) or 0
        ) == 2

    _run(settings, body)


def test_retention_job_is_scheduled_daily_and_setting_is_bounded(monkeypatch) -> None:
    schedule = celery_app.conf.beat_schedule["reward-intent-retention"]
    assert schedule == {"task": "savestream.rewards.retention", "schedule": 86400.0}
    defaults = {field.name: field.default for field in fields(AppSettings)}
    assert defaults["reward_retention_days"] == 365

    monkeypatch.setenv("SAVESTREAM_REWARD_RETENTION_DAYS", "7")
    with pytest.raises(ValueError, match="REWARD_RETENTION_DAYS"):
        AppSettings.from_env()
