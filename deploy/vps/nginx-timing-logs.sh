#!/usr/bin/env bash
# One-time ops change (owner-approved 2026-10-21, QA latency report 2026-10-16).
# Run as root (or with sudo) ON the VPS:
#
#   sudo bash deploy/vps/nginx-timing-logs.sh <deploy-user>
#
# 1. Lets the deploy user read /var/log/nginx (group adm), so Production
#    Diagnostics can see whether a slow request ever reached nginx.
# 2. Adds a timing access log for api.savestream.online with $request_time,
#    $upstream_connect_time, $upstream_response_time and the Cloudflare ray id.
#    It is a separate conf.d file; the existing site config is not edited.
# 3. Checks the config (nginx -t) and reloads nginx gracefully. A reload keeps
#    open connections; recordings run in their own containers and are not
#    touched. Nothing is restarted.
set -Eeuo pipefail

DEPLOY_USER="${1:-${SUDO_USER:-}}"
[[ -n "$DEPLOY_USER" ]] || { echo "usage: $0 <deploy-user>" >&2; exit 2; }
id "$DEPLOY_USER" >/dev/null
[[ "$(id -u)" -eq 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

CONF=/etc/nginx/conf.d/savestream-timing.conf
LOG=/var/log/nginx/savestream-api-timing.log

if id -nG "$DEPLOY_USER" | tr ' ' '\n' | grep -qx adm; then
  echo "$DEPLOY_USER is already in group adm"
else
  usermod -aG adm "$DEPLOY_USER"
  echo "added $DEPLOY_USER to group adm (takes effect on its next login)"
fi

backup=""
if [[ -f "$CONF" ]]; then
  backup="$CONF.bak.$(date +%s)"
  cp -p "$CONF" "$backup"
fi
cat > "$CONF" <<'NGINX'
# SaveStream API timing log (deploy/vps/nginx-timing-logs.sh).
# rt  = total time nginx spent on the request
# uct = time to connect to the API container, urt = API response time
map $host $savestream_api_request {
    default 0;
    api.savestream.online 1;
}
log_format savestream_timing '$time_iso8601 $remote_addr "$request" $status $body_bytes_sent '
                             'rt=$request_time uct=$upstream_connect_time '
                             'urt=$upstream_response_time cf_ray=$http_cf_ray '
                             'proto=$server_protocol';
access_log /var/log/nginx/savestream-api-timing.log savestream_timing if=$savestream_api_request;
NGINX

if nginx -t; then
  touch "$LOG"
  chown www-data:adm "$LOG" 2>/dev/null || true
  chmod 640 "$LOG"
  systemctl reload nginx
  echo "nginx reloaded; timing log: $LOG"
  # An http-level access_log is not inherited by a server block that sets its
  # own access_log: then add the line to the api.savestream.online server.
  if nginx -T 2>/dev/null | awk '/server_name[^;]*api\.savestream\.online/{s=1} s&&/access_log/{print; exit} s&&/^}/{s=0}' | grep -q access_log; then
    echo "NOTE: the api.savestream.online server sets its own access_log; add" >&2
    echo "  access_log $LOG savestream_timing;" >&2
    echo "inside that server block, then run: nginx -t && systemctl reload nginx" >&2
  fi
else
  echo "nginx -t failed; restoring the previous state" >&2
  if [[ -n "$backup" ]]; then mv "$backup" "$CONF"; else rm -f "$CONF"; fi
  nginx -t
  exit 1
fi
