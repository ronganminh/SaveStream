from __future__ import annotations

import threading
import time
from collections import defaultdict

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from app.application.operations.service import OperationalSnapshot


def _escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


class MetricsRegistry:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._requests: dict[tuple[str, str, str], int] = defaultdict(int)
        self._duration_sum: dict[tuple[str, str], float] = defaultdict(float)
        self._duration_count: dict[tuple[str, str], int] = defaultdict(int)

    def observe_http(
        self,
        *,
        method: str,
        route: str,
        status_code: int,
        duration_seconds: float,
    ) -> None:
        with self._lock:
            self._requests[(method, route, str(status_code))] += 1
            self._duration_sum[(method, route)] += duration_seconds
            self._duration_count[(method, route)] += 1

    def render(self, snapshot: OperationalSnapshot) -> str:
        lines = [
            "# HELP savestream_http_requests_total HTTP requests handled.",
            "# TYPE savestream_http_requests_total counter",
        ]
        with self._lock:
            for (method, route, status), value in sorted(self._requests.items()):
                lines.append(
                    'savestream_http_requests_total{method="%s",route="%s",status="%s"} %s'
                    % (_escape(method), _escape(route), _escape(status), value)
                )
            lines.extend(
                [
                    "# HELP savestream_http_request_duration_seconds_sum Total HTTP request duration.",
                    "# TYPE savestream_http_request_duration_seconds_sum counter",
                ]
            )
            for (method, route), duration_value in sorted(self._duration_sum.items()):
                lines.append(
                    'savestream_http_request_duration_seconds_sum{method="%s",route="%s"} %.9f'
                    % (_escape(method), _escape(route), duration_value)
                )
            lines.extend(
                [
                    "# HELP savestream_http_request_duration_seconds_count HTTP requests observed for duration.",
                    "# TYPE savestream_http_request_duration_seconds_count counter",
                ]
            )
            for (method, route), count_value in sorted(self._duration_count.items()):
                lines.append(
                    'savestream_http_request_duration_seconds_count{method="%s",route="%s"} %s'
                    % (_escape(method), _escape(route), count_value)
                )

        gauges: dict[str, int | float] = {
            "savestream_active_recordings": snapshot.active_recordings,
            "savestream_failed_recordings_recent": snapshot.failed_recordings_recent,
            "savestream_pending_outbox_events": snapshot.pending_outbox_events,
            "savestream_unprocessed_payment_events": snapshot.unprocessed_payment_events,
            "savestream_pending_payment_orders": snapshot.pending_payment_orders,
            "savestream_paused_error_watches": snapshot.paused_error_watches,
            "savestream_waiting_for_cloud_slot_recordings": (
                snapshot.waiting_for_cloud_slot_recordings
            ),
            "savestream_missed_no_cloud_slot_recordings": (
                snapshot.missed_no_cloud_slot_recordings
            ),
            "savestream_local_recording_sessions": snapshot.local_recording_sessions,
            "savestream_reward_validity_ratio": snapshot.reward_validity_ratio,
            "savestream_store_transactions": snapshot.store_transactions,
        }
        for name, value in gauges.items():
            lines.append(f"# TYPE {name} gauge")
            lines.append(f"{name} {value}")
        return "\n".join(lines) + "\n"


class MetricsMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp, registry: MetricsRegistry) -> None:
        super().__init__(app)
        self.registry = registry

    async def dispatch(
        self,
        request: Request,
        call_next: RequestResponseEndpoint,
    ) -> Response:
        start = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            route_obj = request.scope.get("route")
            route = getattr(route_obj, "path", request.url.path)
            self.registry.observe_http(
                method=request.method,
                route=str(route),
                status_code=status_code,
                duration_seconds=time.perf_counter() - start,
            )
