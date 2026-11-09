#!/usr/bin/env bash
# READ-ONLY: downloader container log (not for merge).
ENV_FILE="deploy/vps/production.env"; COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
echo "== downloader log"
compose logs --tail=40 --no-log-prefix downloader 2>&1 | grep -vE "password|secret|token" | tail -40
echo "== secret files (names, non-empty?)"
d="$(sed -n 's/^SAVESTREAM_SECRETS_DIR=//p' "$ENV_FILE" | tail -n1)"
for f in video_downloader_proxy_url video_downloader_grant_secret redis_url; do [ -e "$d/$f" ] && echo "$f exists size>0=$([ -s "$d/$f" ] && echo yes || echo no) mode=$(stat -c %a "$d/$f")" || echo "$f MISSING"; done
