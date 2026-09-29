from __future__ import annotations

import time
from pathlib import Path
from typing import Callable

from .contracts import EngineEvent, RecordingRequest, RecordingResult, StopReason
from .exceptions import (
    LiveStreamUnavailableError,
    StreamConnectionError,
    TransientStreamError,
)
from .ports import LiveStreamGateway, MediaProcessor

StopCallback = Callable[[], bool]
EventCallback = Callable[[EngineEvent], None]


class RecordingEngine:
    """Transport-independent one-shot recording engine.

    The engine owns stream-to-disk buffering, stop conditions, minimum-size
    validation and media finalization. It deliberately knows nothing about
    argparse, multiprocessing, Telegram, FastAPI, databases or job queues.
    """

    def __init__(
        self,
        gateway: LiveStreamGateway,
        media_processor: MediaProcessor,
        *,
        clock: Callable[[], float] = time.time,
        sleep: Callable[[float], None] = time.sleep,
        localtime: Callable[[], time.struct_time] = time.localtime,
    ) -> None:
        self.gateway = gateway
        self.media_processor = media_processor
        self._clock = clock
        self._sleep = sleep
        self._localtime = localtime

    def record(
        self,
        request: RecordingRequest,
        *,
        should_stop: StopCallback | None = None,
        on_event: EventCallback | None = None,
        transient_retry_delay_seconds: float = 2.0,
        connection_retry_delay_seconds: float = 0.0,
    ) -> RecordingResult:
        stop_requested = should_stop or (lambda: False)
        emit = on_event or (lambda _event: None)

        live_url = self.gateway.get_live_url(request.room_id)
        if not live_url:
            raise LiveStreamUnavailableError("live stream URL is unavailable")

        timestamp = time.strftime("%Y.%m.%d_%H-%M-%S", self._localtime())
        source_path = request.output_dir / f"TK_{request.username}_{timestamp}_flv.mp4"

        emit(EngineEvent("started", "Started recording"))
        buffer = bytearray()
        bytes_recorded = 0
        stop_reason = StopReason.STREAM_ENDED
        error: str | None = None

        with source_path.open("wb") as out_file:
            done = False
            while not done:
                try:
                    if stop_requested():
                        stop_reason = StopReason.USER_REQUESTED
                        emit(
                            EngineEvent(
                                "stop_requested",
                                "Recording stop requested",
                                bytes_recorded,
                            )
                        )
                        break

                    if not self.gateway.is_room_alive(request.room_id):
                        stop_reason = StopReason.STREAM_ENDED
                        emit(
                            EngineEvent(
                                "stream_ended",
                                "User is no longer live. Stopping recording.",
                                bytes_recorded,
                            )
                        )
                        break

                    # Preserve the legacy recorder semantics: duration is measured
                    # from the beginning of each stream download attempt.
                    attempt_started_at = self._clock()
                    for chunk in self.gateway.download_live_stream(live_url):
                        if stop_requested():
                            stop_reason = StopReason.USER_REQUESTED
                            done = True
                            break

                        buffer.extend(chunk)
                        if len(buffer) >= request.buffer_size:
                            out_file.write(buffer)
                            bytes_recorded += len(buffer)
                            buffer.clear()
                            emit(
                                EngineEvent(
                                    "progress",
                                    "Recording progress",
                                    bytes_recorded,
                                )
                            )

                        elapsed = self._clock() - attempt_started_at
                        if (
                            request.duration_seconds is not None
                            and elapsed >= request.duration_seconds
                        ):
                            stop_reason = StopReason.DURATION_REACHED
                            done = True
                            break

                except StreamConnectionError as exc:
                    emit(
                        EngineEvent(
                            "retrying",
                            "Stream connection closed; retrying",
                            bytes_recorded,
                            {"error": str(exc)},
                        )
                    )
                    if connection_retry_delay_seconds > 0:
                        self._sleep(connection_retry_delay_seconds)

                except TransientStreamError as exc:
                    emit(
                        EngineEvent(
                            "retrying",
                            "Transient stream error; retrying",
                            bytes_recorded,
                            {"error": str(exc)},
                        )
                    )
                    if transient_retry_delay_seconds > 0:
                        self._sleep(transient_retry_delay_seconds)

                except KeyboardInterrupt:
                    stop_reason = StopReason.USER_REQUESTED
                    emit(
                        EngineEvent(
                            "stop_requested",
                            "Recording stopped by user.",
                            bytes_recorded,
                        )
                    )
                    done = True

                except Exception as exc:
                    stop_reason = StopReason.ERROR
                    error = str(exc)
                    emit(
                        EngineEvent(
                            "failed",
                            "Unexpected recording error",
                            bytes_recorded,
                            {"error": error},
                        )
                    )
                    done = True

                finally:
                    if buffer:
                        out_file.write(buffer)
                        bytes_recorded += len(buffer)
                        buffer.clear()
                    out_file.flush()

        try:
            file_size = source_path.stat().st_size
        except OSError:
            file_size = 0

        # Trust the actual file size in case a buffered write occurred after the
        # latest progress callback.
        bytes_recorded = file_size
        if file_size < request.min_valid_bytes:
            emit(
                EngineEvent(
                    "discarded",
                    f"Discarding empty recording ({file_size} bytes)",
                    file_size,
                )
            )
            try:
                source_path.unlink()
            except OSError:
                pass
            return RecordingResult(
                source_path=source_path,
                artifact_path=None,
                bytes_recorded=file_size,
                stop_reason=stop_reason,
                discarded=True,
                error=error,
            )

        emit(EngineEvent("finalizing", "Finalizing recording", file_size))
        artifact_path = self.media_processor.finalize(source_path)
        emit(EngineEvent("completed", "Recording finalized", file_size))
        return RecordingResult(
            source_path=source_path,
            artifact_path=artifact_path,
            bytes_recorded=file_size,
            stop_reason=stop_reason,
            discarded=False,
            error=error,
        )
