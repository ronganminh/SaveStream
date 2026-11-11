#!/usr/bin/env bash
# READ-ONLY verification of the downloader after enabling (not for merge).
# Never prints the proxy URL or any secret; only compares addresses in-process.
ENV_FILE="deploy/vps/production.env"; COMPOSE_FILE="deploy/vps/docker-compose.production.yml"
compose() { COMPOSE_PROFILES=recorder docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
echo "== head $(git rev-parse --short HEAD)"
docker ps --format '{{.Names}} | {{.Status}}' | grep -E "downloader|api-1|recorder"
echo "== startup guard log"; compose logs --no-log-prefix downloader 2>&1 | grep -E "Video downloader|PROXY_URL is not set" | tail -2
echo "== local status: $(curl -s -m 5 http://127.0.0.1:18011/v1/public/video-downloader/status)"
echo "== in-container end-to-end + egress check"
compose exec -T downloader python - <<'PY'
import asyncio, json, socket, threading, time, urllib.request
from urllib.parse import urlsplit
from app.downloader.config import DownloaderSettings

s = DownloaderSettings.from_env()
print("settings: enabled=%s guard_blocked=%s proxy_set=%s" % (s.enabled, s.guard_blocked, bool(s.proxy_url)))
p = urlsplit(s.proxy_url)
proxy_ips = {ai[4][0] for ai in socket.getaddrinfo(p.hostname, p.port or 80, type=socket.SOCK_STREAM)}
proxy_port = p.port or 80
del s, p

def remotes():
    out = set()
    for f in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            rows = open(f).read().splitlines()[1:]
        except OSError:
            continue
        for row in rows:
            parts = row.split()
            rip, rport = parts[2].split(":")
            if parts[3] != "01":  # ESTABLISHED
                continue
            port = int(rport, 16)
            if len(rip) == 8:
                ip = socket.inet_ntoa(bytes.fromhex(rip)[::-1])
            else:
                b = bytes.fromhex(rip)
                ip = socket.inet_ntop(socket.AF_INET6, b"".join(b[i:i+4][::-1] for i in range(0, 16, 4)))
                if ip.startswith("::ffff:"):
                    ip = ip[7:]
            out.add((ip, port))
    return out

seen = set()
stop = False
def sampler():
    while not stop:
        seen.update(remotes())
        time.sleep(0.05)
t = threading.Thread(target=sampler, daemon=True); t.start()

def post(url, body):
    req = urllib.request.Request("http://127.0.0.1:8000" + url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read()), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}"), dict(e.headers)

st, body, h = post("/v1/public/video-downloader/resolve", {"url": "https://www.tiktok.com/@pakesub3/video/7702676085506411809"})
print("allowed video: HTTP", st, "| files:", [(f["label"], f["watermarked"], f["size_bytes"]) for f in body.get("files", [])], "| error:", body.get("error", {}).get("code"))
if st == 200:
    url = body["files"][0]["download_url"]
    with urllib.request.urlopen("http://127.0.0.1:8000" + url, timeout=60) as r:
        got = len(r.read(1_000_000))
        print("  download: HTTP", r.status, r.headers.get("content-type"), "| disposition:", r.headers.get("content-disposition"), "| first bytes read:", got)
st, body, h = post("/v1/public/video-downloader/resolve", {"url": "https://www.tiktok.com/@disney/video/7702910662946721037"})
print("downloads-off video: HTTP", st, "|", body.get("error", {}).get("code"), "|", body.get("error", {}).get("message"))
stop = True; t.join()

ext = {(ip, port) for ip, port in seen if not (ip.startswith(("127.", "172.", "10.", "192.168.")) or ip in ("::1",))}
to_proxy = {c for c in ext if c[0] in proxy_ips and c[1] == proxy_port}
others = ext - to_proxy
print("egress: external connections seen=%d, to the proxy=%d, anywhere else=%d %s" % (len(ext), len(to_proxy), len(others), sorted(others)))
PY
echo "== host public IP (masked) vs. proxy: the downloader container has no route around the proxy for its own requests (trust_env=False, explicit proxy)"
