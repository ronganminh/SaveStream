from __future__ import annotations

import asyncio
import logging
from typing import Any

from app.application.notifications.push import PushDeliveryError

from .celery_app import celery_app

logger = logging.getLogger("savestream.worker")


@celery_app.task(name="savestream.health.ping")
def health_ping() -> str:
    return "pong"


@celery_app.task(name="savestream.watch.check")
def watch_check(watch_id: str, lease_id: str) -> None:
    from app.infrastructure.watches.worker import run_watch_check

    run_watch_check(watch_id, lease_id)


@celery_app.task(name="savestream.watch.scheduler_tick")
def watch_scheduler_tick() -> int:
    from app.infrastructure.watches.worker import run_watch_scheduler_tick

    claims = run_watch_scheduler_tick()
    for watch_id, lease_id in claims:
        watch_check.delay(watch_id, lease_id)
    return len(claims)


@celery_app.task(name="savestream.credits.reconcile")
def credit_reconcile() -> int:
    from app.infrastructure.credits.reconcile import run_reconciliation

    return run_reconciliation()


@celery_app.task(name="savestream.billing.reconcile")
def billing_reconcile() -> int:
    from app.infrastructure.billing.reconcile import run_payment_reconciliation

    return run_payment_reconciliation()


@celery_app.task(name="savestream.operations.alerts")
def operations_alerts() -> int:
    from app.infrastructure.operations.alerts import run_ops_alert_check

    return run_ops_alert_check()


@celery_app.task(name="savestream.privacy.retention")
def privacy_retention() -> dict[str, int]:
    from app.infrastructure.privacy.worker import run_privacy_retention

    return run_privacy_retention()


@celery_app.task(name="savestream.local_recordings.expire")
def local_recordings_expire() -> int:
    from app.infrastructure.local_recordings.worker import (
        expire_local_recording_leases,
    )

    return expire_local_recording_leases()


@celery_app.task(name="savestream.recording.run")
def recording_run(recording_id: str) -> None:
    from app.infrastructure.recording.worker import run_recording_job

    run_recording_job(recording_id)


@celery_app.task(name="savestream.recording.cleanup")
def recording_cleanup(recording_id: str) -> None:
    from app.infrastructure.recording.worker import cleanup_recording

    cleanup_recording(recording_id)


@celery_app.task(name="savestream.recording.recover_stale")
def recording_recover_stale() -> int:
    from app.infrastructure.recording.worker import recover_stale_recordings

    ids = recover_stale_recordings()
    for recording_id in ids:
        recording_run.delay(recording_id)
    return len(ids)


@celery_app.task(name="savestream.notification.b6_scan")
def notification_b6_scan() -> int:
    from app.infrastructure.notifications.b6_worker import (
        run_b6_notification_scan,
    )

    return run_b6_notification_scan()


@celery_app.task(
    bind=True,
    name="savestream.notification.push",
    autoretry_for=(PushDeliveryError,),
    retry_backoff=True,
    retry_jitter=True,
    max_retries=5,
)
def notification_push(self, notification_id: str) -> int:
    del self
    from app.infrastructure.push.worker import run_notification_push

    return run_notification_push(notification_id)


@celery_app.task(name="savestream.admin.storage.orphan_scan")
def admin_storage_orphan_scan(run_id: str) -> None:
    from app.infrastructure.admin.d7_worker import run_orphan_scan

    run_orphan_scan(run_id)


@celery_app.task(name="savestream.admin.storage.orphan_delete")
def admin_storage_orphan_delete(run_id: str) -> None:
    from app.infrastructure.admin.d7_worker import run_orphan_delete

    run_orphan_delete(run_id)


@celery_app.task(name="savestream.admin.broadcast")
def admin_broadcast(broadcast_id: str) -> None:
    from app.infrastructure.admin.d7_worker import run_broadcast

    run_broadcast(broadcast_id)


@celery_app.task(name="savestream.admin.bulk_grant")
def admin_bulk_grant(bulk_grant_id: str) -> None:
    from app.infrastructure.admin.d5_worker import run_bulk_grant

    run_bulk_grant(bulk_grant_id)


@celery_app.task(
    bind=True,
    name="savestream.outbox.event",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_jitter=True,
    max_retries=5,
)
def handle_outbox_event(
    self,
    *,
    event_id: str,
    topic: str,
    payload: dict[str, Any],
) -> None:
    del self
    if topic in {"identity.email.verify_email", "identity.email.password_reset"}:
        from app.infrastructure.email.smtp import deliver_one_time_token_email

        token_id = str(payload.get("token_id", ""))
        asyncio.run(deliver_one_time_token_email(token_id))
        return
    if topic == "notification.push":
        notification_push.delay(str(payload["notification_id"]))
        return
    if topic == "admin.storage.orphan_scan":
        admin_storage_orphan_scan.delay(str(payload["run_id"]))
        return
    if topic == "admin.storage.orphan_delete":
        admin_storage_orphan_delete.delay(str(payload["run_id"]))
        return
    if topic == "admin.broadcast":
        admin_broadcast.delay(str(payload["broadcast_id"]))
        return
    if topic == "admin.bulk_grant":
        admin_bulk_grant.delay(str(payload["bulk_grant_id"]))
        return
    if topic == "recording.requested":
        recording_run.delay(str(payload["recording_id"]))
        return
    if topic == "recording.cleanup":
        recording_cleanup.delay(str(payload["recording_id"]))
        return
    logger.info("outbox event handled id=%s topic=%s", event_id, topic)
