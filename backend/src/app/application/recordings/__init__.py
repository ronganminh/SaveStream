"""Recording application package.

Keep service exports lazy: importing a lightweight submodule such as
``recordings.retention`` from the entitlement service must not eagerly import
the recording service (which depends on quotas and entitlements again).
Celery workers can import tasks concurrently during a cold start, making that
cycle surface intermittently even when the API process starts successfully.
"""

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from .service import RecordingService, RecordingStateStore

__all__ = ["RecordingService", "RecordingStateStore"]


def __getattr__(name: str) -> Any:
    if name in __all__:
        from .service import RecordingService, RecordingStateStore

        return {
            "RecordingService": RecordingService,
            "RecordingStateStore": RecordingStateStore,
        }[name]
    raise AttributeError(name)
