# SaveStream recording engine — Phase 1

Phase 1 extracts the one-shot recording loop from the legacy CLI without rewriting the TikTok behavior that Phase 0 characterized.

## Dependency direction

```text
CLI / future worker
      |
      v
legacy TikTokRecorder orchestration
      |
      +--> TikTokLiveGateway ----> TikTokAPI / HttpClient
      |
      +--> RecordingEngine ------> LiveStreamGateway protocol
      |                         \-> MediaProcessor protocol
      |
      +--> FFmpegMediaProcessor -> VideoManagement / FFmpeg
      |
      \--> Telegram (legacy CLI post-delivery only)
```

`src/engine/` is the reusable boundary. It must not import argparse, multiprocessing, Telegram, FastAPI, database code, Redis/Celery or billing code.

## Engine responsibility

`RecordingEngine.record()` owns:

- stream URL acquisition through a gateway port;
- live checks and stream-to-disk buffering;
- external stop callback checks;
- duration stop behavior;
- retry/backoff hooks for normalized transient transport failures;
- minimum-size garbage recording removal;
- media finalization through a processor port;
- structured `RecordingResult` plus event/progress callbacks.

It does **not** own source monitoring/scheduling, process management, account auth, credits, storage, payment, or API DTOs.

## Compatibility layer

`core.TikTokRecorder` remains for CLI compatibility. Manual/automatic/followers orchestration stays there in Phase 1, but `start_recording()` delegates the actual recording loop to `RecordingEngine`.

This deliberately keeps the existing CLI entry point and modes stable while making the core one-shot operation callable later from a worker.

## Future worker usage

A future worker can compose the same engine without CLI state:

```python
api = TikTokAPI(proxy=proxy, cookies=cookies)
engine = RecordingEngine(
    TikTokLiveGateway(api),
    FFmpegMediaProcessor(),
)
result = engine.record(
    RecordingRequest(
        username=username,
        room_id=room_id,
        output_dir=temp_dir,
    ),
    should_stop=job_stop_requested,
    on_event=publish_progress,
)
```

The worker will later map `RecordingResult` and engine events to the frozen API/DB recording state machine.
