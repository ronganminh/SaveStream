from pathlib import Path

from engine import RecordingEngine, RecordingRequest, StopReason
from engine.exceptions import TransientStreamError


class FakeGateway:
    def __init__(self, chunks: list[bytes], alive: list[bool] | None = None):
        self.chunks = chunks
        self.alive = list(alive or [True, False])
        self.download_calls = 0

    def get_live_url(self, _room_id: str) -> str:
        return "https://cdn.example/live.flv"

    def is_room_alive(self, _room_id: str) -> bool:
        if self.alive:
            return self.alive.pop(0)
        return False

    def download_live_stream(self, _live_url: str):
        self.download_calls += 1
        yield from self.chunks


class FakeProcessor:
    def __init__(self):
        self.calls: list[Path] = []

    def finalize(self, source_path: Path) -> Path:
        self.calls.append(source_path)
        artifact = Path(str(source_path).replace("_flv.mp4", ".mp4"))
        source_path.rename(artifact)
        return artifact


def test_engine_records_and_finalizes_without_cli_dependencies(tmp_path):
    gateway = FakeGateway([b"abc"], alive=[True, False])
    processor = FakeProcessor()
    events = []
    engine = RecordingEngine(gateway, processor)

    result = engine.record(
        RecordingRequest(
            username="creator",
            room_id="room",
            output_dir=tmp_path,
            min_valid_bytes=1,
            buffer_size=2,
        ),
        on_event=events.append,
    )

    assert result.discarded is False
    assert result.stop_reason == StopReason.STREAM_ENDED
    assert result.bytes_recorded == 3
    assert result.artifact_path is not None
    assert result.artifact_path.exists()
    assert len(processor.calls) == 1
    assert any(event.kind == "progress" for event in events)


def test_engine_discards_tiny_recording_before_media_processing(tmp_path):
    gateway = FakeGateway([b"tiny"], alive=[True, False])
    processor = FakeProcessor()
    engine = RecordingEngine(gateway, processor)

    result = engine.record(
        RecordingRequest(
            username="creator",
            room_id="room",
            output_dir=tmp_path,
            min_valid_bytes=100,
        )
    )

    assert result.discarded is True
    assert result.artifact_path is None
    assert processor.calls == []
    assert not result.source_path.exists()


def test_engine_honors_external_stop_callback(tmp_path):
    gateway = FakeGateway([b"ignored"])
    processor = FakeProcessor()
    engine = RecordingEngine(gateway, processor)

    result = engine.record(
        RecordingRequest(
            username="creator",
            room_id="room",
            output_dir=tmp_path,
            min_valid_bytes=1,
        ),
        should_stop=lambda: True,
    )

    assert result.stop_reason == StopReason.USER_REQUESTED
    assert result.discarded is True
    assert processor.calls == []


def test_engine_retries_transient_stream_error(tmp_path):
    class FlakyGateway(FakeGateway):
        def download_live_stream(self, _live_url: str):
            self.download_calls += 1
            if self.download_calls == 1:
                raise TransientStreamError("temporary")
            yield b"payload"

    gateway = FlakyGateway([], alive=[True, True, False])
    processor = FakeProcessor()
    sleeps = []
    engine = RecordingEngine(gateway, processor, sleep=sleeps.append)

    result = engine.record(
        RecordingRequest(
            username="creator",
            room_id="room",
            output_dir=tmp_path,
            min_valid_bytes=1,
        ),
        transient_retry_delay_seconds=2,
    )

    assert result.discarded is False
    assert result.bytes_recorded == len(b"payload")
    assert gateway.download_calls == 2
    assert sleeps == [2]


def test_engine_module_has_no_cli_or_delivery_imports():
    source = Path(__file__).parents[1] / "src" / "engine" / "recording.py"
    text = source.read_text(encoding="utf-8").lower()

    assert "import argparse" not in text
    assert "import multiprocessing" not in text
    assert "from upload.telegram" not in text
    assert "import fastapi" not in text
    assert "from fastapi" not in text
