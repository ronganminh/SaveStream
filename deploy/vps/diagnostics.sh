#!/usr/bin/env bash
# READ-ONLY: outbound IPv4 of the production VPS, spaced so the log shows it
# (owner approved printing it). Not for merge.
ENV_FILE="deploy/vps/production.env"; COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
echo "== host: $(curl -4 -s -m 10 https://ifconfig.me | sed 's/\./ . /g')"
echo "== downloader container: $(compose exec -T downloader curl -4 -s -m 10 https://ifconfig.me < /dev/null | sed 's/\./ . /g')"
