#!/usr/bin/env bash
# READ-ONLY: structure of the live api nginx site (not for merge).
f=/etc/nginx/sites-available/savestream-api
echo "== $f structure"; grep -nE "server \{|listen|server_name|location|proxy_pass|^\s*\}" "$f"
echo "== enabled: $(ls -l /etc/nginx/sites-enabled/ | grep savestream-api)"
