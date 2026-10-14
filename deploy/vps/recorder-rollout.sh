#!/usr/bin/env bash
# Roll the recorder to the freshly built image without cutting recordings.
#
#   bash deploy/vps/recorder-rollout.sh
#
# The recorder runs as one of two Compose services, recorder-blue and
# recorder-green (profile "recorder"). A rollout:
#   1. starts the idle color on the new image and waits until Celery is ready;
#   2. drains the color that was running: its restart policy is set to "no"
#      and it gets SIGTERM, Celery's warm shutdown. It stops taking new jobs at
#      once (unstarted jobs go back to the queue for the new color), finishes
#      the recordings it is running, however long they take, then exits.
# A drained container is removed on the next rollout. While a drain is still
# running, both colors are busy, so the rollout is skipped (the recorder stays
# on its current image) and a later deploy picks it up.
#
# The legacy single `recorder` service is drained the same way on the first
# rollout. Database migrations must stay backward compatible with the
# draining (previous) release, which keeps writing recordings until it exits.
#
# Environment: ENV_FILE, COMPOSE_FILE (as deploy.sh), COMPOSE_PROJECT (Compose
# project name), RECORDER_READY_TIMEOUT (seconds, default 180).
set -Eeuo pipefail

ENV_FILE="${ENV_FILE:-deploy/vps/production.env}"
COMPOSE_FILE="${COMPOSE_FILE:-deploy/vps/docker-compose.production.yml}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-savestream-production}"
READY_TIMEOUT="${RECORDER_READY_TIMEOUT:-180}"

compose() {
  COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

log() { printf '\n==> %s\n' "$*"; }

# "<id> <service> <state> <restart policy>" for every recorder container.
recorder_containers() {
  local id service
  docker ps -aq --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
    | while read -r id; do
        service="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' "$id")"
        case "$service" in
          recorder|recorder-blue|recorder-green)
            docker inspect -f "{{.Id}} ${service} {{.State.Status}} {{.HostConfig.RestartPolicy.Name}}" "$id"
            ;;
        esac
      done
}

log "Recorder containers before rollout"
containers="$(recorder_containers)"
printf '%s\n' "${containers:-none}"

# Remove recorders that already finished draining (exited, restart policy "no").
while read -r id service state policy; do
  [[ -n "${id:-}" ]] || continue
  if [[ "$state" != "running" && "$policy" == "no" ]]; then
    echo "Removing drained ${service} container ${id:0:12}"
    docker rm "$id" >/dev/null
  fi
done <<<"$containers"
containers="$(recorder_containers)"

active_id=""; active_service=""; draining=()
while read -r id service state policy; do
  [[ -n "${id:-}" && "$state" == "running" ]] || continue
  if [[ "$policy" == "no" ]]; then
    draining+=("${service}:${id:0:12}")
  elif [[ -z "$active_id" ]]; then
    active_id="$id"; active_service="$service"
  else
    echo "More than one active recorder (${active_service}, ${service}); fix by hand." >&2
    exit 1
  fi
done <<<"$containers"

if ((${#draining[@]} > 0)); then
  echo "A previous recorder is still draining (${draining[*]}); it is finishing"
  echo "its recordings. Skipping the recorder rollout: ${active_service:-no recorder}"
  echo "keeps running its current image. Deploy again once it has exited."
  exit 0
fi

target="recorder-blue"
[[ "$active_service" == "recorder-blue" ]] && target="recorder-green"

log "Starting ${target} on the new image"
compose up -d --no-deps --no-build "$target"
target_id="$(compose ps -q "$target")"
[[ -n "$target_id" ]] || { echo "${target} did not start" >&2; exit 1; }

log "Waiting for ${target} to accept recording jobs"
ready=false
for _ in $(seq 1 "$READY_TIMEOUT"); do
  if docker logs "$target_id" 2>&1 | grep -q "@.* ready\."; then
    ready=true; break
  fi
  if [[ "$(docker inspect -f '{{.State.Status}}' "$target_id")" != "running" ]]; then
    break
  fi
  sleep 1
done
if [[ "$ready" != "true" ]]; then
  echo "${target} is not ready; stopping it and leaving ${active_service:-the recorder} as is." >&2
  docker logs --tail=80 "$target_id" >&2 || true
  compose stop "$target" >&2 || true
  exit 1
fi
echo "${target} is ready."

if [[ -n "$active_id" ]]; then
  log "Draining ${active_service} (${active_id:0:12})"
  # Without this, Docker would restart the container when Celery exits.
  docker update --restart=no "$active_id" >/dev/null
  # SIGTERM to Celery's main process = warm shutdown: no new jobs, running
  # recordings finish. Not `docker stop`, which would SIGKILL after a timeout.
  docker kill --signal=SIGTERM "$active_id" >/dev/null
  echo "${active_service} stopped taking jobs; it exits after its current recordings."
fi

log "Recorder containers after rollout"
recorder_containers
