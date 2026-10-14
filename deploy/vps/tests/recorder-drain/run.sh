#!/usr/bin/env bash
# End-to-end check of deploy/vps/recorder-rollout.sh with real Docker:
# a long "recording" started on the old recorder must finish there (not be
# cut or restarted) while new jobs go to the new recorder.
#
#   bash deploy/vps/tests/recorder-drain/run.sh
#
# Needs Docker with Compose and Python 3 with pip (to fetch Celery wheels).
set -Eeuo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
rollout="$(cd "$here/../.." && pwd)/recorder-rollout.sh"
work="$(mktemp -d)"
export DATA_DIR="$work/data"
mkdir -p "$DATA_DIR"
chmod 777 "$DATA_DIR"
touch "$work/empty.env"

export ENV_FILE="$work/empty.env" COMPOSE_FILE="$here/compose.yml" COMPOSE_PROJECT=drain-test
dc() { docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }

cleanup() {
  COMPOSE_PROFILES=recorder,tools dc down -v --remove-orphans >/dev/null 2>&1 || true
  docker ps -aq --filter label=com.docker.compose.project=drain-test | xargs -r docker rm -f >/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; COMPOSE_PROFILES=recorder dc logs --tail=40 >&2 || true; exit 1; }
wait_for() { # <file> <seconds>
  for _ in $(seq 1 "$2"); do [[ -f "$DATA_DIR/$1" ]] && return 0; sleep 1; done
  fail "timed out waiting for $1"
}
enqueue() { # <name> <seconds>
  dc run --rm --no-deps -T client python -c \
    "from tasks import record; record.delay('$1', $2)" >/dev/null
}
release_of() { cat "$DATA_DIR/$1"; }
state_of() {
  local status
  status="$(docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null)" && echo "$status" || echo gone
}
rollout() { RELEASE="$1" RECORDER_READY_TIMEOUT=120 bash "$rollout"; }

echo "==> Building the test image"
python3 -m pip download -q -d "$here/wheels" --only-binary=:all: \
  --python-version 3.12 --platform manylinux2014_x86_64 celery redis
RELEASE=1 COMPOSE_PROFILES=recorder,tools dc build -q

echo "==> Release 1 on the legacy single recorder; start a 45 s recording"
RELEASE=1 dc up -d redis recorder
legacy="$(dc ps -q recorder)"
enqueue A 45
wait_for A.started 60
[[ "$(release_of A.started)" == 1 ]] || fail "A did not start on release 1"

echo "==> Deploy release 2 while A records"
rollout 2
blue="$(COMPOSE_PROFILES=recorder dc ps -q recorder-blue)"
[[ -n "$blue" && "$(state_of "$blue")" == running ]] || fail "recorder-blue is not running"
[[ "$(state_of "$legacy")" == running ]] || fail "legacy recorder was stopped while A was recording"

echo "==> New jobs go to release 2"
enqueue B 1
wait_for B.done 60
[[ "$(release_of B.done)" == 2 ]] || fail "B ran on release $(release_of B.done), expected 2"

echo "==> A finishes on release 1, then the legacy recorder exits"
wait_for A.done 90
[[ "$(release_of A.done)" == 1 ]] || fail "A finished on release $(release_of A.done)"
for _ in $(seq 1 30); do [[ "$(state_of "$legacy")" == exited ]] && break; sleep 1; done
[[ "$(state_of "$legacy")" == exited ]] || fail "legacy recorder did not exit after draining"

echo "==> Release 3 swaps blue -> green while blue records C"
enqueue C 30
wait_for C.started 60
rollout 3
green="$(COMPOSE_PROFILES=recorder dc ps -q recorder-green)"
[[ "$(state_of "$green")" == running ]] || fail "recorder-green is not running"
[[ "$(state_of "$legacy")" == gone ]] || fail "drained legacy container was not removed"

echo "==> A rollout while blue still drains C is skipped, not forced"
out="$(rollout 4)"
grep -q "still draining" <<<"$out" || fail "rollout did not skip while draining: $out"
[[ "$(state_of "$blue")" == running ]] || fail "draining blue was stopped"

wait_for C.done 60
[[ "$(release_of C.done)" == 2 ]] || fail "C finished on release $(release_of C.done), expected 2"
for f in A B C; do
  [[ "$(wc -l < "$DATA_DIR/$f.runs")" -eq 1 ]] || fail "$f ran more than once (restarted)"
done

echo "PASS: recordings survived three rollouts"
