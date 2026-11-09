#!/usr/bin/env bash
# READ-ONLY post-deploy check (not for merge).
set -Eeuo pipefail
ENV_FILE="deploy/vps/production.env"; COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
echo "== head $(git rev-parse --short HEAD)"
echo "== containers"; docker ps --format '{{.Names}} | {{.Status}}' | grep savestream-production
echo "== alembic"; compose exec -T api alembic current < /dev/null 2>/dev/null | tail -1
echo "== downloader status (local)"; curl -s -m 5 http://127.0.0.1:18011/v1/public/video-downloader/status; echo
echo "== downloader startup log"; compose logs --tail=20 downloader 2>&1 | grep -iE "downloader|guard|enabled|disabled|error" | tail -5
echo "== downloader limits"; docker inspect savestream-production-downloader-1 --format 'cpus={{.HostConfig.NanoCpus}} mem={{.HostConfig.Memory}} ro={{.HostConfig.ReadonlyRootfs}}' 2>/dev/null
echo "== downloader secrets present (names only)"; compose exec -T downloader sh -c 'ls /run/secrets; test -s /run/secrets/video_downloader_proxy_url && echo proxy=set || echo proxy=empty' < /dev/null
echo "== blocklist sync marker"; compose exec -T redis sh -c 'redis-cli -a "$(cat /run/secrets/redis_password)" --no-auth-warning exists savestream:video_downloader:blocked_videos:synced' < /dev/null
echo "== public route via nginx"; curl -s -o /dev/null -w '%{http_code}\n' https://api.savestream.online/v1/public/video-downloader/status
