from __future__ import annotations

import asyncio
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

import app.application.public_reports as public_reports
from app.application.public_reports import parse_target
from app.infrastructure.db.admin_models import AdminComplaintCase, AdminComplaintEvent
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings

COPYRIGHT = {
    "kind": "copyright",
    "email": "R.Okafor@Example.com",
    "name": "Rachel Okafor",
    "relationship": "agent",
    "work_description": "Live concert 'Night Tour' (2026)\nOriginal on our channel.",
    "locations": "https://www.tiktok.com/@kbeats.live/live",
    "good_faith": True,
    "accurate_and_authorized": True,
    "signature": "Rachel Okafor",
}

ABUSE = {
    "kind": "abuse",
    "email": "creator@example.com",
    "target": "@dance.studio",
    "reporter_role": "self",
    "description": "Someone records my private LIVE every night.",
}


def _app(tmp_path, **overrides):
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'reports.db'}"
    settings = replace(identity_settings(database_url), **overrides)
    create_schema(database_url)
    return create_app(settings), database_url


def _cases(database_url: str) -> list[tuple[AdminComplaintCase, list[AdminComplaintEvent]]]:
    async def run():
        database = Database(database_url)
        try:
            async with database.session() as session:
                cases = (await session.scalars(select(AdminComplaintCase))).all()
                out = []
                for case in cases:
                    events = (
                        await session.scalars(
                            select(AdminComplaintEvent).where(
                                AdminComplaintEvent.complaint_id == case.id
                            )
                        )
                    ).all()
                    out.append((case, list(events)))
                return out
        finally:
            await database.close()

    return asyncio.run(run())


def test_parse_target_reads_handles_urls_and_recording_links() -> None:
    assert parse_target("@kbeats.live").channel_username == "kbeats.live"
    assert parse_target("kbeats.live").channel_username == "kbeats.live"
    assert parse_target("https://www.tiktok.com/@kbeats.live/live").channel_username == "kbeats.live"
    link = parse_target(
        "https://savestream.online/recordings/3f9a21c4-1111-4000-8000-000000000000"
    )
    assert str(link.recording_id) == "3f9a21c4-1111-4000-8000-000000000000"
    assert parse_target("see the attached screenshots").channel_username is None


def test_copyright_notice_creates_a_safety_case(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post("/v1/public/reports", json=COPYRIGHT)

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["kind"] == "copyright"
    assert body["reference"].startswith("SR-") and len(body["reference"]) == 11

    [(case, events)] = _cases(database_url)
    assert case.kind == "copyright"
    assert case.status == "new"
    assert case.created_by_user_id is None
    assert case.complainant_email == "r.okafor@example.com"
    assert case.channel_source_type == "username"
    assert case.channel_source_value == "kbeats.live"
    assert "Electronic signature: Rachel Okafor" in case.body
    assert case.summary.startswith("Copyright notice: Live concert")
    assert body["reference"] == "SR-" + case.id.hex[:8].upper()
    assert [event.action for event in events] == ["created"]


def test_abuse_report_creates_a_safety_case(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post("/v1/public/reports", json=ABUSE)

    assert response.status_code == 201, response.text
    [(case, _)] = _cases(database_url)
    assert case.kind == "abuse"
    assert case.channel_source_value == "dance.studio"
    assert "Is the reporter the person in the stream: Yes, it's me" in case.body


def test_copyright_notice_requires_both_statements(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post(
            "/v1/public/reports", json={**COPYRIGHT, "accurate_and_authorized": False}
        )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert _cases(database_url) == []


def test_reports_are_rate_limited_per_ip(tmp_path) -> None:
    app, _ = _app(tmp_path, public_report_rate_limit=2)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        codes = [client.post("/v1/public/reports", json=ABUSE).status_code for _ in range(3)]

    assert codes == [201, 201, 429]


def test_turnstile_is_required_when_a_secret_is_configured(tmp_path, monkeypatch) -> None:
    seen: list[str] = []

    async def fake_verify(secret: str, token: str, remote_ip: str) -> bool:
        seen.append(token)
        return token == "good-token"

    monkeypatch.setattr(public_reports, "verify_turnstile", fake_verify)
    app, database_url = _app(tmp_path, turnstile_secret_key="test-secret")
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        missing = client.post("/v1/public/reports", json=ABUSE)
        bad = client.post("/v1/public/reports", json={**ABUSE, "turnstile_token": "bad"})
        good = client.post("/v1/public/reports", json={**ABUSE, "turnstile_token": "good-token"})

    assert missing.status_code == 400
    assert missing.json()["error"]["code"] == "CAPTCHA_FAILED"
    assert bad.status_code == 400
    assert good.status_code == 201
    assert seen == ["bad", "good-token"]
    assert len(_cases(database_url)) == 1


def test_filled_honeypot_looks_successful_but_stores_nothing(tmp_path) -> None:
    app, database_url = _app(tmp_path)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post(
            "/v1/public/reports", json={**ABUSE, "website": "https://spam.example"}
        )

    assert response.status_code == 201
    assert response.json()["reference"].startswith("SR-")
    assert _cases(database_url) == []
