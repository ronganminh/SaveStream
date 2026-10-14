#!/usr/bin/env bash
# Production backend deploy, run ON the VPS from the repository root after
# `git pull --ff-only origin main` (the Deploy Backend workflow does both).
#
#   bash deploy/vps/deploy.sh [--allow-active-recordings] [--skip-backup]
#
# Steps: refuse while cloud recordings are running (restarting the recorder
# would cut them), take a pg_dump backup, validate Compose, rebuild and start
# every service (the api container runs `alembic upgrade head` on start),
# wait for health, then check migrations, health endpoints and admin CORS.
# Never runs `docker compose down -v`.
set -Eeuo pipefail

ALLOW_ACTIVE_RECORDINGS=false
SKIP_BACKUP=false
for arg in "$@"; do
  case "$arg" in
    --allow-active-recordings) ALLOW_ACTIVE_RECORDINGS=true ;;
    --skip-backup) SKIP_BACKUP=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

ENV_FILE="deploy/vps/production.env"
COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
API_URL="${SAVESTREAM_PUBLIC_API_URL:-https://api.savestream.online}"
WEB_ORIGIN="${SAVESTREAM_PUBLIC_WEB_ORIGIN:-https://savestream.online}"

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

log() { printf '\n==> %s\n' "$*"; }

[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 1; }
[[ -f "$COMPOSE_FILE" ]] || { echo "Missing $COMPOSE_FILE" >&2; exit 1; }

log "Revision $(git rev-parse --short HEAD) on $(git branch --show-current)"

log "Checking for in-flight cloud recordings"
active_recordings="$(compose exec -T postgres psql -U savestream -d savestream -tAc \
  "select count(*) from recordings where deleted_at is null and status in \
   ('resolving','waiting_live','recording','stop_requested','processing','uploading')" \
  | tr -d '[:space:]' || echo "unknown")"
echo "Active recordings: ${active_recordings}"
if [[ "$active_recordings" != "0" && "$ALLOW_ACTIVE_RECORDINGS" != "true" ]]; then
  echo "Refusing to restart the recorder while recordings are running." >&2
  echo "Re-run later, or pass --allow-active-recordings to accept cutting them." >&2
  exit 3
fi

if [[ "$SKIP_BACKUP" != "true" ]]; then
  log "Backing up PostgreSQL"
  mkdir -p backups
  backup="backups/predeploy-$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD).dump"
  compose exec -T postgres pg_dump -U savestream -d savestream -Fc > "$backup"
  [[ -s "$backup" ]] || { echo "Backup $backup is empty" >&2; exit 1; }
  ls -lh "$backup"
fi

log "Validating Compose configuration"
compose config --quiet

log "Building and starting services"
compose up -d --build --remove-orphans

log "Waiting for the api container to become healthy"
api_container="$(compose ps -q api)"
for _ in $(seq 1 60); do
  health="$(docker inspect -f '{{.State.Health.Status}}' "$api_container" 2>/dev/null || echo starting)"
  [[ "$health" == "healthy" ]] && break
  sleep 5
done
if [[ "$health" != "healthy" ]]; then
  echo "api is $health after 5 minutes" >&2
  compose logs --tail=150 api >&2
  exit 1
fi

compose ps

log "Alembic revision"
compose exec -T api alembic current

log "Health endpoints"
curl -fsS "${API_URL}/health/live" && echo
curl -fsS "${API_URL}/health/ready" && echo

log "Admin CORS preflight"
cors_headers="$(curl -fsS -D - -o /dev/null -X OPTIONS \
  "${API_URL}/v1/admin/credits/adjustments" \
  -H "Origin: ${WEB_ORIGIN}" \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: authorization,content-type,idempotency-key,x-admin-step-up,x-request-id')"
grep -qi "access-control-allow-origin: ${WEB_ORIGIN}" <<<"$cors_headers" \
  || { echo "CORS origin header missing" >&2; exit 1; }
grep -qi "x-admin-step-up" <<<"$cors_headers" \
  || { echo "CORS X-Admin-Step-Up header missing" >&2; exit 1; }

log "Recent api logs"
compose logs --tail=40 api

log "Deploy finished: $(git rev-parse --short HEAD)"
