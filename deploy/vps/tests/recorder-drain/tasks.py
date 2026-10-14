"""Stand-in for the recorder: a Celery task that "records" for N seconds."""

import os
import pathlib
import time

from celery import Celery

app = Celery("drain", broker=os.environ["BROKER_URL"])
app.conf.update(
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_routes={"record": {"queue": "recordings"}},
)

DATA = pathlib.Path("/data")


@app.task(name="record")
def record(name: str, seconds: float) -> None:
    version = os.environ.get("RELEASE", "?")
    with (DATA / f"{name}.runs").open("a") as runs:
        runs.write(version + "\n")
    (DATA / f"{name}.started").write_text(version)
    time.sleep(seconds)
    (DATA / f"{name}.done").write_text(version)
