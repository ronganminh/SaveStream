#!/usr/bin/env bash
# Read-only production diagnostics, run ON the VPS from the repository root
# (the Production Diagnostics workflow does this over SSH).
#
#   bash deploy/vps/diagnostics.sh [days]
#
# Prints recording outcomes and failure reasons, recent recorder/worker error
# log lines and data-cleanup checks. It never writes to the database, never
# restarts containers and prints no email addresses or secrets.
set -Eeuo pipefail

DAYS="${1:-7}"
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "days must be a number" >&2; exit 2; }

ENV_FILE="deploy/vps/production.env"
COMPOSE_FILE="deploy/vps/docker-compose.production.yml"

compose() {
  # The "recorder" profile includes recorder-blue/green (see recorder-rollout.sh).
  COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

sql() {
  # -X ignores psqlrc; default_transaction_read_only blocks any write.
  compose exec -T postgres psql -X -U savestream -d savestream -P pager=off \
    -c "set default_transaction_read_only = on;" -c "$1" < /dev/null
}

section() { printf '\n==> %s\n' "$*"; }

section "Revision $(git rev-parse --short HEAD), last ${DAYS} day(s)"
compose ps
echo "Recorder containers (a running one with restart policy \"no\" is draining):"
docker ps -a --filter label=com.docker.compose.project=savestream-production \
  --format '{{.Names}} {{.Status}}' | grep -i recorder || echo "none"

section "Recordings by status"
sql "select status, count(*) as jobs, sum(duration_seconds)/60 as minutes
     from recordings
     where created_at >= now() - interval '${DAYS} days'
     group by status order by jobs desc;"

section "Failed / stopped recordings by reason"
sql "select status, coalesce(error_code, '-') as error_code, count(*) as jobs,
            left(max(coalesce(error_message, '')), 300) as sample_message
     from recordings
     where created_at >= now() - interval '${DAYS} days'
       and status in ('failed', 'stopped', 'missed_no_cloud_slot')
     group by status, error_code order by jobs desc;"

section "Latest 25 failed / stopped recordings"
sql "select created_at, status,
            coalesce(resolved_username, source_value) as creator,
            duration_seconds, worker_attempts,
            coalesce(error_code, '-') as error_code,
            left(coalesce(error_message, ''), 200) as error_message
     from recordings
     where created_at >= now() - interval '${DAYS} days'
       and status in ('failed', 'stopped')
     order by created_at desc limit 25;"

section "Active recordings (heartbeat age = seconds since the worker last checked in)"
sql "select id, status, coalesce(resolved_username, source_value) as creator,
            started_at, updated_at,
            extract(epoch from now() - heartbeat_at)::int as heartbeat_age_s,
            duration_seconds, bytes_recorded / 1048576 as mib, worker_attempts
     from recordings
     where deleted_at is null
       and status in ('queued', 'resolving', 'waiting_live', 'recording',
                      'processing', 'uploading', 'stop_requested')
     order by created_at;"

section "Recent recordings: status timeline and artifacts"
sql "select r.id, coalesce(r.resolved_username, r.source_value) as creator, r.status,
            r.duration_seconds, r.bytes_recorded / 1048576 as mib,
            (select count(*) from artifacts a
              where a.recording_id = r.id and a.deleted_at is null) as artifacts,
            (select string_agg(to_char(e.created_at, 'HH24:MI') || ' ' || e.event_type, ', '
                               order by e.sequence)
               from recording_events e where e.recording_id = r.id) as timeline_utc
     from recordings r
     where r.created_at >= now() - interval '${DAYS} days'
     order by r.created_at desc limit 15;"

# Every running recorder container, including the legacy `recorder` and a
# draining color, which `compose ps` no longer lists by service.
for id in $(docker ps -q --filter "label=com.docker.compose.project=savestream-production"); do
  service="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' "$id")"
  [[ "$service" == recorder* ]] || continue
  section "${service}: local recording files and upload connections"
  docker exec "$id" sh -c '
    dir="${SAVESTREAM_RECORDING_TEMP_DIR:-/tmp/savestream-recordings}"
    find "$dir" -type f -printf "%TY-%Tm-%Td %TH:%TM  %10s bytes  %p\n" 2>/dev/null | sort || true
    echo "-- established TCP connections to port 443 (remote, send-queue bytes):"
    awk "NR>1 && \$4==\"01\" && substr(\$3, index(\$3, \":\")+1)==\"01BB\" {print \$3, \$5}" \
      /proc/net/tcp /proc/net/tcp6 2>/dev/null || true
  ' || true
  section "${service}: upload log lines (last 24h, newest 40)"
  docker logs --since 24h "$id" 2>&1 \
    | grep -Ei 'upload|retry|timeout|reset|broken pipe|stalled' \
    | grep -Eiv 'password|secret|token|authorization' \
    | tail -n 40 || true
done

section "Creator avatars: cached copy status and latency (3 tries each)"
# The cached URLs are public (served by /v1/public/creator-avatars).
sql "select coalesce(resolved_username, source_value) as creator,
            creator_avatar_cached_url is not null as cached,
            creator_avatar_refreshed_at
     from watches where deleted_at is null order by updated_at desc limit 20;"
compose exec -T postgres psql -X -U savestream -d savestream -tA \
  -c "select creator_avatar_cached_url from watches
      where deleted_at is null and creator_avatar_cached_url is not null
      order by updated_at desc limit 8;" < /dev/null \
  | while read -r url; do
      [[ -n "$url" ]] || continue
      for _ in 1 2 3; do
        curl -s -o /dev/null -m 30 -w "%{http_code} %{time_total}s %{size_download}B  " "$url" || true
      done
      printf ' %s\n' "${url##*/}"
    done

section "Object storage (R2 S3 endpoint) errors in api/worker/recorder logs (24h)"
for id in $(docker ps -q --filter "label=com.docker.compose.project=savestream-production"); do
  service="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' "$id")"
  docker logs --since 24h "$id" 2>&1 \
    | grep -Ei 'r2\.cloudflarestorage|S3Error|ServiceUnavailable|SlowDown|\b503\b|MaxRetryError|creator-avatars/[0-9a-f]+ HTTP/1\.1" 5' \
    | grep -Eiv 'password|secret|token|authorization|X-Amz-Signature' \
    | tail -n 15 | sed "s/^/${service}: /" || true
done

section "Watch checks: failures by error (last 24h)"
sql "select left(coalesce(error, '-'), 160) as error, count(*) as checks
     from admin_watch_check_metrics
     where checked_at >= now() - interval '24 hours' and success = false
     group by 1 order by checks desc limit 15;"

section "BUG-6 cleanup: watches with invalid sources"
sql "select status, last_error, count(*) as watches
     from watches
     where deleted_at is null and last_error = 'invalid_tiktok_source'
     group by status, last_error;"
sql "select source_type, left(source_value, 60) as source_value, status, last_error
     from watches
     where deleted_at is null
       and source_type = 'username'
       and source_value !~ '^@?[A-Za-z0-9._]{2,24}\$';"

section "BUG-4: payment orders still created/pending"
sql "select provider, status, count(*) as orders, min(created_at) as oldest
     from payment_orders
     where status in ('created', 'pending')
     group by provider, status;"

for service in recorder-blue recorder-green worker scheduler; do
  section "${service}: error lines (last 24h, newest 80)"
  compose logs --no-color --since 24h "$service" 2>&1 \
    | grep -Ev '\] (INFO|DEBUG)/' \
    | grep -Ei '\b(error|exception|traceback|failed|denied|forbidden)\b|\b(403|429|5[0-9]{2})\b' \
    | grep -Eiv 'password|secret|token|authorization' \
    | tail -n 80 || true
done

section "PayPal readiness (no secrets printed; OAuth token check only, nothing is bought)"
compose exec -T api python - <<'PY' || echo "PayPal check could not run"
import httpx
from app.settings import get_app_settings

s = get_app_settings()
base = s.payment_provider_base_url
mode = "LIVE" if base == "https://api-m.paypal.com" else "SANDBOX" if "sandbox" in base else "other"
print(f"provider={s.payment_provider} mode={mode} base={base}")
print(f"client_id={'set' if s.paypal_client_id else 'MISSING'} ({len(s.paypal_client_id)} chars)"
      f" client_secret={'set' if s.paypal_client_secret else 'MISSING'}")
print(f"return_base={s.frontend_base_url} reconcile_every={s.payment_reconcile_seconds}s"
      f" pending_expiry={s.payment_pending_expiry_seconds}s")
if s.payment_provider == "paypal" and s.paypal_client_id and s.paypal_client_secret:
    try:
        r = httpx.post(f"{base}/v1/oauth2/token", data={"grant_type": "client_credentials"},
                       auth=(s.paypal_client_id, s.paypal_client_secret), timeout=15)
        body = r.json() if r.headers.get("content-type", "").startswith("application/json") else {}
        print(f"oauth_status={r.status_code} app_id={body.get('app_id', '-')}"
              f" error={body.get('error', '-')}")
    except Exception as exc:  # noqa: BLE001
        print(f"oauth_error={type(exc).__name__}")
PY
sql "select key, value from admin_runtime_settings where key like 'payment%' order by key;" \
  || echo "runtime settings table not readable"
sql "select provider, status, count(*) as orders, max(updated_at) as latest
     from payment_orders group by provider, status order by provider, status;"

section "Media links as the API signs them (latest completed recording; links are not printed)"
compose exec -T api python - <<'PY' || echo "media link check could not run"
import asyncio
from urllib.parse import urlparse

import httpx
from sqlalchemy import select

from app.application.recordings.download import attachment_disposition, download_filename
from app.infrastructure.db.recording_models import RecordingArtifact as Artifact, Recording
from app.infrastructure.db.session import Database
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import get_app_settings


async def main() -> None:
    s = get_app_settings()
    db = Database(s.database_url)
    try:
        async with db.session() as session:
            row = (
                await session.execute(
                    select(Artifact, Recording)
                    .join(Recording, Recording.id == Artifact.recording_id)
                    .where(Recording.status == "completed", Artifact.storage_key.like("%.mp4"))
                    .order_by(Artifact.created_at.desc())
                    .limit(1)
                )
            ).first()
    finally:
        await db.close()
    if row is None:
        print("no completed recording")
        return
    artifact, recording = row
    minio = MinioStorageClient(s)
    play = minio.presigned_get_url(artifact.storage_key)
    name = download_filename(recording)
    save = minio.presigned_get_url(
        artifact.storage_key, content_disposition=attachment_disposition(name)
    )
    print(f"link host: {urlparse(play).netloc}")
    print(f"expected file name: {name}")
    with httpx.Client(timeout=30) as client:
        r = client.get(play, headers={"Range": "bytes=0-1023"})
        print(f"play  range 0-1023 -> {r.status_code} {r.headers.get('content-type')} "
              f"content-range={r.headers.get('content-range')} bytes={len(r.content)}")
        r = client.get(save, headers={"Range": "bytes=0-1023"})
        print(f"download range    -> {r.status_code} disposition={r.headers.get('content-disposition')}")
        with client.stream("GET", save) as r:
            print(f"download full GET -> {r.status_code} length={r.headers.get('content-length')} "
                  f"disposition={r.headers.get('content-disposition')}")


asyncio.run(main())
PY

section "API latency incident window (read-only)"
# QA 2026-10-16: GET /v1/me 30.5s from 08:38:45, POST /v1/auth/login 24.1s,
# both done ~08:39:15.6 UTC; normal (~0.3s) right after.
SINCE="${INCIDENT_SINCE:-2026-10-16T08:36:00Z}"
UNTIL="${INCIDENT_UNTIL:-2026-10-16T08:42:00Z}"
echo "window: $SINCE .. $UNTIL (now $(date -u +%FT%TZ))"
echo "-- host"
uptime || true
nproc || true
free -m || true
df -h / | tail -n 1 || true
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io 2>/dev/null || true
docker stats --no-stream --format '{{.Name}} cpu={{.CPUPerc}} mem={{.MemUsage}} ({{.MemPerc}}) pids={{.PIDs}}' 2>/dev/null || true
echo "-- kernel OOM / hung task messages (if readable)"
(dmesg -T 2>/dev/null || journalctl -k --since "$SINCE" --no-pager 2>/dev/null || true) \
  | grep -Ei 'oom|killed process|hung_task|blocked for more than' | tail -n 10 || true
echo "-- containers: started, restarts, OOM, health log"
for id in $(docker ps -aq --filter "label=com.docker.compose.project=savestream-production"); do
  docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}} started={{.State.StartedAt}} restarts={{.RestartCount}} oom={{.State.OOMKilled}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}-{{end}}' "$id"
  docker inspect -f '{{if .State.Health}}{{range .State.Health.Log}}   health {{.Start}} exit={{.ExitCode}}{{"\n"}}{{end}}{{end}}' "$id" | tail -n 6
done
echo "-- slowest API requests in the nginx timing log, last ${DAYS} day(s) (rt = total, urt = API)"
if [[ -r /var/log/nginx/savestream-api-timing.log ]]; then
  awk '{for (i = 1; i <= NF; i++) if ($i ~ /^rt=/) {split($i, a, "="); print a[2], $0}}' \
    /var/log/nginx/savestream-api-timing.log \
    | sort -rn | head -n 15 | cut -d' ' -f2- | sed -E 's/\?[^ "]*/?…/g' || true
else
  echo "timing log not readable yet (run deploy/vps/nginx-timing-logs.sh as root)"
fi
echo "-- deploy user can sudo without a password?"
sudo -n true 2>/dev/null && echo yes || echo no
echo "-- api processes (uvicorn workers)"
docker top "$(compose ps -q api)" -o pid,etime,pcpu,rss,args 2>/dev/null | sed -E 's/(token|secret|password)=[^ ]*/\1=***/gi' || true
for service in api worker scheduler outbox-dispatcher postgres redis; do
  id="$(compose ps -q "$service" 2>/dev/null | head -n 1)"
  [[ -n "$id" ]] || continue
  echo "-- $service log lines in window (query strings removed)"
  docker logs --timestamps --since "$SINCE" --until "$UNTIL" "$id" 2>&1 \
    | grep -Eiv 'password|secret|authorization|X-Amz-Signature' \
    | sed -E 's/\?[^ "]*/?…/g; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email>/g' \
    | tail -n 120 || true
done
for name in $(docker ps -a --filter label=com.docker.compose.project=savestream-production --format '{{.Names}}' | grep -i recorder); do
  echo "-- $name log lines in window"
  docker logs --timestamps --since "$SINCE" --until "$UNTIL" "$name" 2>&1 \
    | grep -Eiv 'password|secret|authorization|X-Amz-Signature|https?://' | tail -n 40 || true
done
echo "-- api access lines per 5 s in window (a gap = API not answering)"
docker logs --timestamps --since "$SINCE" --until "$UNTIL" "$(compose ps -q api)" 2>&1 \
  | grep -E '" [0-9]{3}' | cut -c12-19 | awk '{split($1,t,":"); s=t[3]-t[3]%5; printf "%s:%s:%02d\n", t[1], t[2], s}' \
  | uniq -c || true
echo "-- postgres: settings, connections, locks, long queries"
sql "select name, setting from pg_settings where name in
     ('max_connections','shared_buffers','log_min_duration_statement','log_lock_waits',
      'deadlock_timeout','idle_in_transaction_session_timeout','statement_timeout');"
sql "select coalesce(application_name,'-') as app, state, count(*),
            max(now() - query_start)::text as longest
     from pg_stat_activity where datname = 'savestream' group by 1, 2 order by 3 desc;"
sql "select pid, state, wait_event_type, wait_event, (now() - query_start)::text as running,
            left(regexp_replace(query, '\s+', ' ', 'g'), 120) as query
     from pg_stat_activity
     where datname = 'savestream' and state <> 'idle' and pid <> pg_backend_pid()
     order by query_start limit 10;"
sql "select count(*) as waiting_locks from pg_locks where not granted;"
sql "select datname, deadlocks, temp_files, xact_rollback, blks_read, blks_hit,
            stats_reset::text from pg_stat_database where datname = 'savestream';"
sql "select checkpoints_timed, checkpoints_req, buffers_checkpoint, stats_reset::text
     from pg_stat_bgwriter;" 2>/dev/null || true
sql "select count(*) > 0 as pg_stat_statements_installed
     from pg_extension where extname = 'pg_stat_statements';"
sql "select calls, round(mean_exec_time::numeric, 1) as mean_ms,
            round(max_exec_time::numeric, 1) as max_ms,
            left(regexp_replace(query, '\s+', ' ', 'g'), 140) as query
     from pg_stat_statements order by max_exec_time desc limit 15;" 2>/dev/null \
  || echo "pg_stat_statements not available"
sql "select relname, n_live_tup, n_dead_tup, last_autovacuum::text, last_autoanalyze::text
     from pg_stat_user_tables order by n_dead_tup desc limit 8;"
echo "-- redis"
compose exec -T redis redis-cli INFO clients < /dev/null | grep -E 'connected_clients|blocked_clients' || true
compose exec -T redis redis-cli INFO memory < /dev/null | grep -E 'used_memory_human|maxmemory_human|mem_fragmentation_ratio' || true
compose exec -T redis redis-cli INFO persistence < /dev/null | grep -E 'rdb_last_bgsave_status|rdb_last_save_time|aof_enabled|rdb_bgsave_in_progress|latest_fork_usec' || true
compose exec -T redis redis-cli SLOWLOG GET 10 < /dev/null | head -n 80 || true
compose exec -T redis redis-cli LATENCY LATEST < /dev/null || true
echo "-- app metrics: mean seconds per route since the api started (slowest 15)"
compose exec -T api sh -c 'tok=""; for f in /run/secrets/metrics_token; do [ -r "$f" ] && tok="$(cat "$f")"; done; [ -n "$tok" ] || tok="${SAVESTREAM_METRICS_TOKEN:-}"; curl -s -m 10 -H "X-Metrics-Token: $tok" http://localhost:8000/metrics' < /dev/null 2>/dev/null \
  | awk '/duration_seconds_sum\{/ {match($0,/\{[^}]*\}/); k=substr($0,RSTART,RLENGTH); s[k]=$NF}
         /duration_seconds_count\{/ {match($0,/\{[^}]*\}/); k=substr($0,RSTART,RLENGTH); c[k]=$NF}
         END {for (k in s) if (c[k] > 0) printf "%.3f s mean over %d  %s\n", s[k]/c[k], c[k], k}' \
  | sort -rn | head -n 15 || true
echo "-- api settings that bound waits (no secrets)"
compose exec -T api python - <<'PY' 2>/dev/null || true
from app.settings import AppSettings
s = AppSettings.from_env()
for name in sorted(vars(s)):
    if any(k in name for k in ("timeout", "pool", "worker", "rate_limit", "rate_window")):
        print(name, "=", getattr(s, name))
PY

section "Host nginx around the incident (read-only, if readable)"
ls -la /var/log/nginx/ 2>&1 | head -n 12 || true
for f in /var/log/nginx/savestream-api-timing.log /var/log/nginx/access.log /var/log/nginx/error.log; do
  [[ -r "$f" ]] || { echo "$f not readable by $(id -un)"; continue; }
  echo "-- $f lines 15:38:30-15:39:30 local (08:38:30-08:39:30 UTC), api host only, query strings removed"
  grep -E '16/Oct/2026:15:3(8:[3-5][0-9]|9:[0-2][0-9])|2026/10/16 15:3(8:[3-5][0-9]|9:[0-2][0-9])' "$f" \
    | grep -Eiv 'password|secret|authorization' \
    | sed -E 's/\?[^ "]*/?…/g; s/^([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+/\1.x.x/' | tail -n 80 || true
done
nginx -T 2>/dev/null | grep -Ei 'worker_connections|worker_processes|keepalive_timeout|http2|log_format|proxy_read_timeout|limit_req|limit_conn' | head -n 20 \
  || grep -rhEi 'worker_connections|worker_processes|log_format|limit_req|limit_conn' /etc/nginx/nginx.conf /etc/nginx/sites-enabled/ 2>/dev/null | head -n 20 || true
echo "-- auth token lifetimes"
compose exec -T api python - <<'PY' 2>/dev/null || true
from app.settings import AppSettings
s = AppSettings.from_env()
for name in sorted(vars(s)):
    if ("ttl" in name or "expire" in name or "lifetime" in name) and "secret" not in name:
        print(name, "=", getattr(s, name))
PY
echo "-- web sessions created/revoked 08:30-08:45 UTC (no user ids)"
sql "select date_trunc('second', coalesce(revoked_at, created_at))::text as at,
            client_type, coalesce(revoked_reason, 'created') as what, count(*)
     from auth_sessions
     where (created_at between '2026-10-16 08:30:00+00' and '2026-10-16 08:45:00+00')
        or (revoked_at between '2026-10-16 08:30:00+00' and '2026-10-16 08:45:00+00')
     group by 1, 2, 3 order by 1;"

section "Done"
