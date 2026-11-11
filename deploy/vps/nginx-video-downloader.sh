#!/usr/bin/env bash
# One-time ops change (owner-approved 2026-11-11): route the public video
# downloader through nginx. Run as root (or with sudo) ON the VPS:
#
#   sudo bash deploy/vps/nginx-video-downloader.sh
#
# Adds `location /v1/public/video-downloader/` (proxied to the `downloader`
# container on 127.0.0.1:18011, unbuffered) to the api.savestream.online site,
# right before its `location /` block. Everything else keeps going to the API.
# Idempotent: does nothing if the route is already there. Keeps a backup,
# checks the config with `nginx -t` (restoring the backup if it fails) and
# reloads gracefully: open connections and LIVE recordings are not touched.
set -Eeuo pipefail

SITE="${1:-/etc/nginx/sites-available/savestream-api}"
[[ "$(id -u)" -eq 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
[[ -f "$SITE" ]] || { echo "nginx site file not found: $SITE" >&2; exit 1; }

if grep -q "location /v1/public/video-downloader/" "$SITE"; then
  echo "route already present in $SITE; nothing to do"
  exit 0
fi

tmp="$(mktemp)"
awk '
  { lines[NR] = $0 }
  END {
    done = 0
    for (i = 1; i <= NR; i++) {
      if (!done && lines[i] ~ /^[[:space:]]*location \/ \{[[:space:]]*$/) {
        api = 0
        for (j = i + 1; j <= i + 3 && j <= NR; j++)
          if (lines[j] ~ /proxy_pass http:\/\/127\.0\.0\.1:18001;/) api = 1
        if (api) {
          print "    # Public video downloader: its own container (docker-compose"
          print "    # `downloader`). Added by deploy/vps/nginx-video-downloader.sh."
          print "    location /v1/public/video-downloader/ {"
          print "        proxy_pass http://127.0.0.1:18011;"
          print "        proxy_http_version 1.1;"
          print "        proxy_set_header Host $host;"
          print "        proxy_set_header X-Forwarded-Proto https;"
          print "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
          print "        proxy_set_header X-Request-ID $request_id;"
          print ""
          print "        client_max_body_size 16k;"
          print "        proxy_buffering off;"
          print "        proxy_request_buffering off;"
          print "        proxy_max_temp_file_size 0;"
          print "        proxy_read_timeout 300s;"
          print "        proxy_send_timeout 300s;"
          print "    }"
          print ""
          done = 1
        }
      }
      print lines[i]
    }
    if (!done) exit 3
  }
' "$SITE" > "$tmp" || { rm -f "$tmp"; echo "could not find the API 'location /' block (proxy_pass 127.0.0.1:18001) in $SITE; nothing changed" >&2; exit 1; }

backup="$SITE.bak-$(date -u +%Y%m%dT%H%M%SZ)"
cp -p "$SITE" "$backup"
cat "$tmp" > "$SITE"
rm -f "$tmp"

if nginx -t; then
  systemctl reload nginx
  echo "route added to $SITE (backup: $backup); nginx reloaded"
else
  cp -p "$backup" "$SITE"
  echo "nginx -t failed; restored $SITE from $backup, nothing reloaded" >&2
  exit 1
fi
