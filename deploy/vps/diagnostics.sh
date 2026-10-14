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
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

sql() {
  # -X ignores psqlrc; default_transaction_read_only blocks any write.
  compose exec -T postgres psql -X -U savestream -d savestream -P pager=off \
    -c "set default_transaction_read_only = on;" -c "$1" < /dev/null
}

section() { printf '\n==> %s\n' "$*"; }

section "Revision $(git rev-parse --short HEAD), last ${DAYS} day(s)"
compose ps

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

for service in recorder recorder-blue recorder-green; do
  id="$(compose ps -q "$service" 2>/dev/null || true)"
  [[ -n "$id" ]] || continue
  section "${service}: local recording files and upload connections"
  docker exec "$id" sh -c '
    dir="${SAVESTREAM_RECORDING_TEMP_DIR:-/tmp/savestream-recordings}"
    find "$dir" -type f -printf "%TY-%Tm-%Td %TH:%TM  %10s bytes  %p\n" 2>/dev/null | sort || true
    echo "-- established TCP connections to port 443 (remote, send-queue bytes):"
    awk "NR>1 && \$4==\"01\" && substr(\$3, index(\$3, \":\")+1)==\"01BB\" {print \$3, \$5}" \
      /proc/net/tcp /proc/net/tcp6 2>/dev/null || true
  ' || true
  section "${service}: upload log lines (last 24h, newest 40)"
  compose logs --no-color --since 24h "$service" 2>&1 \
    | grep -Ei 'upload|retry|timeout|reset|broken pipe|stalled' \
    | grep -Eiv 'password|secret|token|authorization' \
    | tail -n 40 || true
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

for service in recorder worker scheduler; do
  section "${service}: error lines (last 24h, newest 80)"
  compose logs --no-color --since 24h "$service" 2>&1 \
    | grep -Ev '\] (INFO|DEBUG)/' \
    | grep -Ei '\b(error|exception|traceback|failed|denied|forbidden)\b|\b(403|429|5[0-9]{2})\b' \
    | grep -Eiv 'password|secret|token|authorization' \
    | tail -n 80 || true
done

section "Done"
