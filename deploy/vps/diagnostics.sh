#!/usr/bin/env bash
# READ-ONLY: outbound IPs of the production VPS (not for merge).
ENV_FILE="deploy/vps/production.env"; COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
echo "== host IPv4 (ifconfig.me): $(curl -4 -s -m 10 https://ifconfig.me || echo none)"
echo "== host IPv4 (api.ipify.org): $(curl -4 -s -m 10 https://api.ipify.org || echo none)"
echo "== host IPv6 (ifconfig.me): $(curl -6 -s -m 10 https://ifconfig.me || echo none)"
echo "== host IPv6 (api64.ipify.org): $(curl -6 -s -m 10 https://api64.ipify.org || echo none)"
echo "== downloader container IPv4: $(compose exec -T downloader curl -4 -s -m 10 https://ifconfig.me < /dev/null || echo none)"
echo "== downloader container IPv6: $(compose exec -T downloader curl -6 -s -m 10 https://ifconfig.me < /dev/null || echo none)"
echo "== host global addresses:"; ip -o addr show scope global | awk '{print $2, $3, $4}'
echo "== docker IPv6 enabled on backend network: $(docker network inspect savestream-production_backend --format '{{.EnableIPv6}}' 2>/dev/null)"
