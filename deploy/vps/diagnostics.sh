#!/usr/bin/env bash
# READ-ONLY: what is running on the production VPS (not for merge).
set -Eeuo pipefail
echo "== checkout: branch=$(git branch --show-current) head=$(git rev-parse --short HEAD) origin/main=$(git rev-parse --short origin/main 2>/dev/null)"
echo "== dirty files (names only):"; git status --porcelain | cut -c4- | head -20
echo "== local branches:"; git branch --format='%(refname:short)'
echo "== containers (name | image | status):"
docker ps -a --format '{{.Names}} | {{.Image}} | {{.Status}}'
echo "== compose projects:"; docker compose ls -a 2>/dev/null || true
echo "== images mentioning download/chrom/playwright:"; docker images --format '{{.Repository}}:{{.Tag}}' | grep -iE 'download|chrom|playwright' || echo none
echo "== downloader files present on disk?"; ls -la deploy/vps/docker-compose.download-worker.yml 2>/dev/null || echo "docker-compose.download-worker.yml: not present"
