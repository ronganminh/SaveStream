from __future__ import annotations

from celery import Celery

from app.settings import AppSettings, get_app_settings


def create_celery_app(settings: AppSettings | None = None) -> Celery:
    cfg = settings or get_app_settings()
    app = Celery(
        "savestream",
        broker=cfg.celery_broker_url,
        backend=cfg.celery_result_backend,
        include=["app.infrastructure.queue.tasks"],
    )
    app.conf.update(
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="UTC",
        enable_utc=True,
        task_acks_late=True,
        worker_prefetch_multiplier=1,
        broker_connection_retry_on_startup=True,
        # Recordings hold a worker slot for the whole livestream. Routing them to
        # their own queue lets a dedicated worker cap system-wide concurrency
        # without starving watch checks and other short tasks.
        task_routes={"savestream.recording.run": {"queue": cfg.recording_queue}},
        beat_schedule={
            "recover-stale-recordings": {
                "task": "savestream.recording.recover_stale",
                "schedule": 60.0,
            },
            "watch-scheduler-tick": {
                "task": "savestream.watch.scheduler_tick",
                "schedule": float(cfg.watch_scheduler_tick_seconds),
            },
            "credit-reconciliation": {
                "task": "savestream.credits.reconcile",
                "schedule": 3600.0,
            },
            "payment-reconciliation": {
                "task": "savestream.billing.reconcile",
                "schedule": float(cfg.payment_reconcile_seconds),
            },
            "operations-alert-check": {
                "task": "savestream.operations.alerts",
                "schedule": float(cfg.ops_alert_check_seconds),
            },
            "privacy-retention": {
                "task": "savestream.privacy.retention",
                "schedule": float(cfg.retention_check_seconds),
            },
            "b6-retention-notifications": {
                "task": "savestream.notification.b6_scan",
                "schedule": float(cfg.retention_check_seconds),
            },
        },
    )
    return app


celery_app = create_celery_app()
