#!/usr/bin/env bash
# Production backend deploy, run ON the VPS from the repository root after
# `git pull --ff-only origin main` (the Deploy Backend workflow does both).
#
#   bash deploy/vps/deploy.sh [--skip-backup]
#
# Steps: take a pg_dump backup, validate Compose, build images, restart every
# service except the recorder (the api container runs `alembic upgrade head`
# on start), wait for health, roll the recorder over without cutting running
# recordings (deploy/vps/recorder-rollout.sh), then check migrations, health
# endpoints and admin CORS. Deploys no longer wait for recordings to finish.
# Never runs `docker compose down -v`.
set -Eeuo pipefail

SKIP_BACKUP=false
for arg in "$@"; do
  case "$arg" in
    # Obsolete: the recorder now drains instead of being restarted.
    --allow-active-recordings) echo "--allow-active-recordings is no longer needed; ignoring it." ;;
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

log "In-flight cloud recordings (they keep running; the recorder drains)"
compose exec -T postgres psql -U savestream -d savestream -tAc \
  "select count(*) from recordings where deleted_at is null and status in \
   ('resolving','waiting_live','recording','stop_requested','processing','uploading')" \
  || true

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

log "Building images (recorder included)"
COMPOSE_PROFILES=recorder compose build

# Everything but the recorder restarts in place. Without the "recorder"
# profile, `config --services` leaves recorder-blue/green out, and no
# --remove-orphans: that would kill the legacy `recorder` container mid-recording.
log "Starting services (recorder excluded)"
mapfile -t services < <(compose config --services)
compose up -d --no-build "${services[@]}"

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

log "Rolling the recorder over (running recordings finish on the old one)"
ENV_FILE="$ENV_FILE" COMPOSE_FILE="$COMPOSE_FILE" bash deploy/vps/recorder-rollout.sh

COMPOSE_PROFILES=recorder compose ps

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
