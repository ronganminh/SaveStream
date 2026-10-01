from __future__ import annotations

import asyncio
import subprocess
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import StreamingResponse

MEDIA_PATH = Path("/tmp/savestream-e2e-stream.flv")
app = FastAPI(title="SaveStream E2E Stream", docs_url=None, redoc_url=None)


def ensure_media() -> None:
    if MEDIA_PATH.exists() and MEDIA_PATH.stat().st_size > 700_000:
        return
    MEDIA_PATH.unlink(missing_ok=True)
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc=size=640x360:rate=25",
            "-t",
            "8",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-b:v",
            "1M",
            "-pix_fmt",
            "yuv420p",
            "-f",
            "flv",
            str(MEDIA_PATH),
        ],
        check=True,
    )
    if MEDIA_PATH.stat().st_size <= 700_000:
        raise RuntimeError("E2E stream fixture is too small")


@app.on_event("startup")
async def startup() -> None:
    await asyncio.to_thread(ensure_media)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/alive/{room_id}")
async def alive(room_id: str) -> dict[str, bool]:
    return {"alive": room_id != "offline"}


@app.get("/stream.flv")
async def stream(room_id: str = "e2e-room") -> StreamingResponse:
    del room_id

    async def body():
        with MEDIA_PATH.open("rb") as source:
            while chunk := source.read(8192):
                yield chunk
                await asyncio.sleep(0.04)

    return StreamingResponse(body(), media_type="video/x-flv")


def main() -> None:
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8090, log_level="warning")


if __name__ == "__main__":
    main()
