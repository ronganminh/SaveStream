#!/usr/bin/env bash
# READ-ONLY check of the web ownership policy in production (not for merge).
# Runs the app's own policy and the Android (mobile) filters against real rows
# inside a READ ONLY transaction that is rolled back. Prints no emails,
# usernames or ids (only short hashes and counts).
set -Eeuo pipefail
ENV_FILE="deploy/vps/production.env"
COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }

echo "== production.env sets SAVESTREAM_WEB_REQUIRE_OWNERSHIP?"
grep -E '^\s*SAVESTREAM_WEB_REQUIRE_OWNERSHIP=' "$ENV_FILE" || echo "not set there (compose default applies)"
echo "== deployed commit: $(git rev-parse --short HEAD)"
for svc in api scheduler; do
  echo "== $svc effective env: $(compose exec -T $svc printenv SAVESTREAM_WEB_REQUIRE_OWNERSHIP < /dev/null || echo '(unset)')"
done

compose exec -T api python - <<'PY'
import asyncio, hashlib, uuid
from sqlalchemy import select, text
from app.settings import get_app_settings
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.models import UserNotification
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.domain.common.errors import ApplicationError
from app.api.schemas.recordings import Source
from app.application.watches.ownership import (
    WEB_BASES, is_web_only, may_record, watch_username, mobile_hidden_resources,
)
from app.application.watches.verification import ensure_recording_source_verified
from app.application.watches.service import WatchService
from app.application.recordings.service import RecordingService
from app.application.notifications.service import NotificationService

def h(v): return hashlib.sha256(str(v).encode()).hexdigest()[:8]

async def main():
    s = get_app_settings()
    print("settings: web_require_ownership =", s.web_require_ownership,
          "| channel_verification_enforced =", s.channel_verification_enforced)
    db = Database(s.database_url)
    try:
        async with db.session() as session:
            await session.execute(text("SET TRANSACTION READ ONLY"))
            rows = (await session.execute(text(
                "SELECT added_via, ownership_basis, owner_verified_at IS NOT NULL v, "
                "blocked_at IS NOT NULL b, deleted_at IS NOT NULL d, count(*) "
                "FROM watches GROUP BY 1,2,3,4,5 ORDER BY 6 DESC"))).all()
            print("watches by added_via/basis/verified/blocked/deleted:")
            for r in rows: print("  ", tuple(r))
            live = [w for w in (await session.scalars(select(Watch).where(Watch.deleted_at.is_(None)))).all()
                    if is_web_only(w) and w.blocked_at is None]
            users = sorted({w.user_id for w in live}, key=str)
            print(f"live unblocked web-only channels: {len(live)} across {len(users)} accounts")
            ok = True
            for uid in users[:10]:
                scopes = scopes_for_role("user")
                web = AuthPrincipal(uid, uuid.uuid4(), "user", scopes, client_type="web")
                app = AuthPrincipal(uid, uuid.uuid4(), "user", scopes, client_type="mobile")
                mine = [w for w in live if w.user_id == uid]
                wl = await WatchService(session, s).list(web, limit=200, cursor=None, status=None)
                ml = await WatchService(session, s).list(app, limit=200, cursor=None, status=None)
                web_ids = {w.id for w in wl.items}; app_ids = {w.id for w in ml.items}
                for w in mine:
                    name = watch_username(w)
                    src = Source(type="username", value=name) if name else None
                    async def gate(ct):
                        if src is None: return "n/a"
                        try:
                            await ensure_recording_source_verified(session, s, user_id=uid, source=src, client_type=ct)
                            return "allowed"
                        except ApplicationError as e:
                            return e.code
                    res = {
                        "basis": w.ownership_basis,
                        "web_may_record": may_record(w, s, client_type="web"),
                        "auto_record_may_record": may_record(w, s, client_type=None),
                        "app_may_record": may_record(w, s, client_type="mobile"),
                        "web_start": await gate("web"),
                        "app_start": await gate("mobile"),
                        "in_web_list": w.id in web_ids,
                        "in_app_list": w.id in app_ids,
                    }
                    good = (res["web_may_record"] and res["web_start"] == "allowed"
                            and not res["app_may_record"] and res["app_start"] != "allowed"
                            and res["in_web_list"] and not res["in_app_list"])
                    ok &= good
                    print(f"  acct {h(uid)} ch {h(w.id)}:", res, "OK" if good else "MISMATCH")
                hid_w, hid_r = await mobile_hidden_resources(session, uid)
                wr = await RecordingService(session, s).list(web, limit=100, cursor=None, status=None)
                ar = await RecordingService(session, s).list(app, limit=100, cursor=None, status=None)
                leaked_r = [r for r in ar.items if str(r.id) in hid_r]
                wn = await NotificationService(session).list(web, limit=100, cursor=None, unread_only=False)
                an = await NotificationService(session).list(app, limit=100, cursor=None, unread_only=False)
                leaked_n = [n for n in an.items if (n.resource_type == "watch" and n.resource_id in hid_w)
                            or (n.resource_type == "recording" and n.resource_id in hid_r)]
                web_hidden_r = sum(1 for r in wr.items if str(r.id) in hid_r)
                web_hidden_n = sum(1 for n in wn.items if (n.resource_type == "watch" and n.resource_id in hid_w)
                                   or (n.resource_type == "recording" and n.resource_id in hid_r))
                print(f"  acct {h(uid)}: recordings web={len(wr.items)} (web-only {web_hidden_r}) app={len(ar.items)} leaked_to_app={len(leaked_r)};"
                      f" notifications web={len(wn.items)} (web-only {web_hidden_n}) app={len(an.items)} leaked_to_app={len(leaked_n)}")
                ok &= not leaked_r and not leaked_n
            print("RESULT:", "PASS" if ok else "FAIL")
            await session.rollback()
    finally:
        await db.close()
asyncio.run(main())
PY
