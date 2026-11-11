#!/usr/bin/env bash
# READ-ONLY: what enabling the downloader needs on the host (not for merge).
# Never reads secret contents.
ENV_FILE="deploy/vps/production.env"
echo "== whoami: $(id -un) groups: $(id -Gn)"
echo "== passwordless sudo: $(sudo -n true 2>/dev/null && echo yes || echo no)"
sudo -n -l 2>/dev/null | sed -n '1,20p' | grep -vE "secure_path|env_" || true
echo "== nginx files mentioning api.savestream.online:"
grep -rl "api.savestream.online" /etc/nginx/ 2>/dev/null | while read -r f; do echo "$f $(stat -c '%U:%G %a' "$f") writable=$([ -w "$f" ] && echo yes || echo no)"; done
echo "== existing downloader route: $(grep -rl 'video-downloader' /etc/nginx/ 2>/dev/null || echo none)"
echo "== server_name / proxy_pass lines in the api file:"
f=$(grep -rl "api.savestream.online" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null | head -1); [ -n "$f" ] && grep -nE "server_name|listen|location|proxy_pass|include" "$f"
echo "== production.env: $(stat -c '%U:%G %a' "$ENV_FILE") writable=$([ -w "$ENV_FILE" ] && echo yes || echo no)"
echo "== downloader-related keys present (names only):"; grep -oE '^SAVESTREAM_(VIDEO_DOWNLOADER|TURNSTILE|CORS|FRONTEND|DOWNLOADER)[A-Z_]*' "$ENV_FILE" || echo none
d="$(sed -n 's/^SAVESTREAM_SECRETS_DIR=//p' "$ENV_FILE" | tail -n1)"
echo "== proxy secret file: size=$(stat -c %s "$d/video_downloader_proxy_url") mode=$(stat -c %a "$d/video_downloader_proxy_url")"
echo "== downloader on 127.0.0.1:18011 status: $(curl -s -m 5 http://127.0.0.1:18011/v1/public/video-downloader/status)"
