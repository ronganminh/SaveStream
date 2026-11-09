#!/usr/bin/env bash
# READ-ONLY post-deploy check (not for merge).
ENV_FILE="deploy/vps/production.env"; COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
sleep 20
echo "== head $(git rev-parse --short HEAD)"
docker ps --format '{{.Names}} | {{.Status}}' | grep savestream-production
echo "== downloader status"; curl -s -m 5 http://127.0.0.1:18011/v1/public/video-downloader/status; echo
echo "== downloader log"; compose logs --tail=8 --no-log-prefix downloader 2>&1 | grep -vE "password|secret" | tail -5
echo "== limits"; docker inspect savestream-production-downloader-1 --format 'cpus={{.HostConfig.NanoCpus}} mem={{.HostConfig.Memory}} ro={{.HostConfig.ReadonlyRootfs}} capadd={{.HostConfig.CapAdd}} capdrop={{.HostConfig.CapDrop}}'
echo "== blocklist synced marker"; compose exec -T redis sh -c 'redis-cli -a "$(cat /run/secrets/redis_password)" --no-auth-warning exists savestream:video_downloader:blocked_videos:synced' < /dev/null
echo "== public via nginx (expect 404 until owner adds the route)"; curl -s -o /dev/null -w '%{http_code}\n' https://api.savestream.online/v1/public/video-downloader/status
echo "== report endpoint on API (GET -> 405 means route exists)"; curl -s -o /dev/null -w '%{http_code}\n' https://api.savestream.online/v1/public/video-downloader-reports
