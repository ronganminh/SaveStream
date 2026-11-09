"""Video downloader takedown reports, the blocklist and its Redis copy."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.application.video_downloader.blocklist import BlocklistService, sync_to_redis
from app.domain.common.errors import ApplicationError
from app.downloader.state import BLOCKLIST_KEY, BLOCKLIST_SYNCED_KEY
from app.infrastructure.db.admin_models import (
    AdminComplaintCase,
    VideoDownloadBlock,
    VideoDownloadReport,
)
from app.infrastructure.db.models import User
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings

VIDEO_ID = "7702676085506411809"
VIDEO_URL = f"https://www.tiktok.com/@shop.live/video/{VIDEO_ID}?is_from_webapp=1"
REPORT = {
    "video_url": VIDEO_URL,
    "reporter_name": "Mai Tran",
    "reporter_email": "Mai@Example.com",
    "relationship": "creator",
    "reason": "copyright",
    "details": "This is my video, please remove it from the tool.",
    "good_faith": True,
}


class FakeRedis:
    def __init__(self) -> None:
        self.sets: dict[str, set[str]] = {}
        self.values: dict[str, str] = {}
        self.fail = False

    async def sadd(self, name: str, *values: str) -> int:
        if self.fail:
            raise ConnectionError("redis down")
        self.sets.setdefault(name, set()).update(values)
        return len(values)

    async def srem(self, name: str, *values: str) -> int:
        if self.fail:
            raise ConnectionError("redis down")
        self.sets.setdefault(name, set()).difference_update(values)
        return len(values)

    async def delete(self, *names: str) -> int:
        for name in names:
            self.sets.pop(name, None)
            self.values.pop(name, None)
        return len(names)

    def pipeline(self, transaction: bool = True) -> FakePipeline:
        return FakePipeline(self)


class FakePipeline:
    def __init__(self, redis: FakeRedis) -> None:
        self.redis = redis
        self.ops: list[tuple[str, tuple[Any, ...]]] = []

    def sadd(self, name: str, *values: str) -> None:
        self.ops.append(("sadd", (name, *values)))

    def rename(self, src: str, dst: str) -> None:
        self.ops.append(("rename", (src, dst)))

    def delete(self, name: str) -> None:
        self.ops.append(("delete", (name,)))

    def set(self, name: str, value: str) -> None:
        self.ops.append(("set", (name, value)))

    async def execute(self) -> None:
        for op, args in self.ops:
            if op == "sadd":
                self.redis.sets.setdefault(args[0], set()).update(args[1:])
            elif op == "rename":
                self.redis.sets[args[1]] = self.redis.sets.pop(args[0])
            elif op == "delete":
                self.redis.sets.pop(args[0], None)
            else:
                self.redis.values[args[0]] = args[1]


def _app(tmp_path, **overrides):
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'dl.db'}"
    settings = replace(identity_settings(database_url), **overrides)
    create_schema(database_url)
    return create_app(settings), database_url


def _rows(database_url: str) -> tuple[list[Any], list[Any], list[Any]]:
    async def run():
        database = Database(database_url)
        try:
            async with database.session() as session:
                return (
                    list((await session.scalars(select(VideoDownloadReport))).all()),
                    list((await session.scalars(select(VideoDownloadBlock))).all()),
                    list((await session.scalars(select(AdminComplaintCase))).all()),
                )
        finally:
            await database.close()

    return asyncio.run(run())


def _client(app, redis: FakeRedis) -> TestClient:
    client = TestClient(app, base_url="https://testserver")
    client.__enter__()
    app.state.rate_limiter = InMemoryRateLimiter()
    app.state.redis = SimpleNamespace(client=redis)
    return client


def test_report_blocks_the_video_at_once_and_opens_a_case(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    redis = FakeRedis()
    client = _client(app, redis)
    try:
        response = client.post("/v1/public/video-downloader-reports", json=REPORT)
    finally:
        client.__exit__(None, None, None)
    assert response.status_code == 201, response.text
    reference = response.json()["reference"]
    assert reference.startswith("DL-") and len(reference) == 9
    assert redis.sets[BLOCKLIST_KEY] == {VIDEO_ID}

    [report], [block], [case] = _rows(database_url)
    assert report.reference == reference
    assert report.reporter_email == "mai@example.com"
    assert report.complaint_id == case.id
    assert (block.video_id, block.source, block.report_id) == (VIDEO_ID, "report", report.id)
    assert block.unblocked_at is None
    assert case.kind == "copyright" and case.status == "new"
    assert VIDEO_ID in case.summary


def test_report_validation(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    redis = FakeRedis()
    client = _client(app, redis)
    try:
        short = client.post(
            "/v1/public/video-downloader-reports",
            json={**REPORT, "video_url": "https://vm.tiktok.com/ZMabc123/"},
        )
        other = client.post(
            "/v1/public/video-downloader-reports",
            json={**REPORT, "video_url": "https://youtube.com/watch?v=1"},
        )
        no_statement = client.post(
            "/v1/public/video-downloader-reports", json={**REPORT, "good_faith": False}
        )
        honeypot = client.post(
            "/v1/public/video-downloader-reports", json={**REPORT, "website": "spam"}
        )
    finally:
        client.__exit__(None, None, None)
    assert short.json()["error"]["code"] == "INVALID_LINK"
    assert "full video link" in short.json()["error"]["message"]
    assert other.json()["error"]["code"] == "INVALID_LINK"
    assert no_statement.status_code == 400
    assert honeypot.status_code == 201
    assert _rows(database_url) == ([], [], [])
    assert BLOCKLIST_KEY not in redis.sets


def test_reports_are_rate_limited(tmp_path) -> None:
    app, _ = _app(tmp_path)
    client = _client(app, FakeRedis())
    try:
        codes = [
            client.post("/v1/public/video-downloader-reports", json=REPORT).status_code
            for _ in range(6)
        ]
    finally:
        client.__exit__(None, None, None)
    assert codes == [201] * 5 + [429]


def test_failed_redis_push_makes_the_downloader_refuse(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    redis = FakeRedis()
    redis.values[BLOCKLIST_SYNCED_KEY] = "x"
    redis.fail = True
    client = _client(app, redis)
    try:
        response = client.post("/v1/public/video-downloader-reports", json=REPORT)
    finally:
        client.__exit__(None, None, None)
    assert response.status_code == 201
    # The block is in the database; the marker is gone, so the downloader
    # refuses everything until the next full sync.
    assert BLOCKLIST_SYNCED_KEY not in redis.values
    assert len(_rows(database_url)[1]) == 1


def test_manual_block_unblock_and_full_sync(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'sync.db'}"
    create_schema(database_url)

    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                admin = User(email="ops@example.com", normalized_email="ops@example.com", role="admin")
                session.add(admin)
                await session.flush()
                service = BlocklistService(session)
                await service.block(video_url=VIDEO_URL, reason="Rights holder email", actor_id=admin.id)
                other = "https://www.tiktok.com/@b/video/7000000000000000001"
                await service.block(video_url=other, reason="Test", actor_id=admin.id)
                await service.unblock("7000000000000000001", reason="Mistake", actor_id=admin.id)
                with pytest.raises(ApplicationError):
                    await service.unblock("7000000000000000001", reason="Again", actor_id=admin.id)
                with pytest.raises(ApplicationError):
                    await service.block(
                        video_url="https://vt.tiktok.com/ZSabc12/", reason="x", actor_id=admin.id
                    )
                await session.commit()

                redis = FakeRedis()
                redis.sets[BLOCKLIST_KEY] = {"stale"}
                assert await sync_to_redis(session, redis) == 1
                assert redis.sets[BLOCKLIST_KEY] == {VIDEO_ID}
                assert BLOCKLIST_SYNCED_KEY in redis.values

                # Re-blocking an unblocked video reuses its row.
                row = await service.block(video_url=other, reason="Again", actor_id=admin.id)
                assert row.unblocked_at is None and row.unblock_reason is None
                await service.unblock(VIDEO_ID, reason="Resolved", actor_id=uuid.uuid4())
                await session.commit()
                empty = FakeRedis()
                assert await sync_to_redis(session, empty) == 1
                assert empty.sets[BLOCKLIST_KEY] == {"7000000000000000001"}
        finally:
            await database.close()

    asyncio.run(run())
