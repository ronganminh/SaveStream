from __future__ import annotations

from dataclasses import replace

from app.application.operations.service import (
    OperationalSnapshot,
    evaluate_alerts,
)
from app.infrastructure.metrics.registry import MetricsRegistry
from tests.identity_helpers import identity_settings


def test_phase8_alert_thresholds_and_metrics_render() -> None:
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        ops_outbox_alert_threshold=2,
        ops_failed_recording_alert_threshold=3,
        ops_payment_event_alert_threshold=4,
        ops_paused_watch_alert_threshold=5,
    )
    snapshot = OperationalSnapshot(
        active_recordings=1,
        failed_recordings_recent=3,
        pending_outbox_events=2,
        unprocessed_payment_events=4,
        pending_payment_orders=7,
        paused_error_watches=5,
        waiting_for_cloud_slot_recordings=6,
        missed_no_cloud_slot_recordings=2,
        local_recording_sessions=4,
        reward_validity_ratio=0.75,
        store_transactions=9,
    )
    alerts = evaluate_alerts(snapshot, settings)
    assert {item.code for item in alerts} == {
        "outbox_backlog",
        "recording_failures",
        "payment_events_unprocessed",
        "watches_paused_error",
    }

    registry = MetricsRegistry()
    registry.observe_http(
        method="GET",
        route="/v1/recordings/{recording_id}",
        status_code=200,
        duration_seconds=0.25,
    )
    rendered = registry.render(snapshot)
    assert "savestream_http_requests_total" in rendered
    assert 'route="/v1/recordings/{recording_id}"' in rendered
    assert "savestream_pending_outbox_events 2" in rendered
    assert "savestream_unprocessed_payment_events 4" in rendered
    assert "savestream_waiting_for_cloud_slot_recordings 6" in rendered
    assert "savestream_missed_no_cloud_slot_recordings 2" in rendered
    assert "savestream_local_recording_sessions 4" in rendered
    assert "savestream_reward_validity_ratio 0.75" in rendered
    assert "savestream_store_transactions 9" in rendered
