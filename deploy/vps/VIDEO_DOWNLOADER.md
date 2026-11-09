# Video downloader (web "Free tools")

A public tool on the website: paste a TikTok link, get TikTok's own
downloadable file. It runs in its own container (`downloader` in
`docker-compose.production.yml`) and is **off** until every step below is done.

## What it does and does not do

- Only public videos whose creator allows downloads (TikTok's
  `downloadSetting`). If the setting is off, or cannot be read, the video is
  refused.
- Only TikTok's own download file (the one its Save button gives, with TikTok's
  watermark). The watermark-free play stream is never served to the public.
- Private, friends-only and removed videos are refused; no cookies, logins or
  browser automation are used.
- Files stream straight from TikTok to the visitor. Nothing is written to disk
  or R2; Redis holds the media link for at most 10 minutes.
- Limits: 10 link checks per hour per IP, Turnstile from the 6th, videos up to
  10 minutes or 300 MB, at most 4 downloads at once.
- Providers: SaveStream's own page reader, then yt-dlp (pinned). gallery-dl
  is not used (GPL-2.0).
- Container limits: 0.5 CPU, 512 MB RAM, read-only filesystem, no Linux
  capabilities. Secrets: Redis URL, proxy URL, grant key. No database,
  storage, JWT or mail credentials.

## Turning it on (owner)

1. **Egress proxy (required).** Without it the downloader refuses to enable in
   production, so its traffic can never come from the IP LIVE recording uses.
   See "Egress" below. Write the proxy URL into the secret file (one line, no
   quotes):

   ```
   $SAVESTREAM_SECRETS_DIR/video_downloader_proxy_url
   # e.g. http://USER:PASSWORD@203.0.113.10:3128
   ```

   `SAVESTREAM_SECRETS_DIR` is set in `deploy/vps/production.env`. `deploy.sh`
   creates this file empty, and creates `video_downloader_grant_secret` with a
   random value; never print or commit either.

2. **nginx.** Add the `location /v1/public/video-downloader/` block from
   `nginx-production.conf.example` to the API server block, then
   `sudo nginx -t && sudo systemctl reload nginx`.

3. **Turnstile (recommended).** In `deploy/vps/production.env` set
   `SAVESTREAM_TURNSTILE_SECRET_KEY=...` (Cloudflare Turnstile secret). Without
   it the tool stops at 5 checks per hour per IP instead of asking for a check.

4. **Flag.** In `deploy/vps/production.env` set
   `SAVESTREAM_VIDEO_DOWNLOADER_ENABLED=true`, then run the Deploy Backend
   workflow (it drains the recorder as usual).

5. Check `curl https://api.savestream.online/v1/public/video-downloader/status`
   shows `"enabled": true`. If it stays false, `docker compose logs downloader`
   says why (for example the proxy guard).

The report blocklist must have been copied to Redis by the API before the
tool serves anything (fail closed); the API does this on start.

To turn it off: set `SAVESTREAM_VIDEO_DOWNLOADER_ENABLED=false` and deploy, or
empty the proxy URL file and restart the `downloader` container.

## Egress

Every request the downloader makes (TikTok pages, short links and the video
files themselves) goes through `video_downloader_proxy_url`. The video bytes
pass through the proxy, so its traffic allowance is what matters.

**Cheapest option that fits:** a small second VPS used only as a forward
proxy, from a different provider or datacenter than the main server, so it
has an unrelated IP.

- 1 vCPU, 1–2 GB RAM, 10–20 GB disk, one dedicated IPv4.
- At least 2 TB of traffic included per month (about 200,000 downloads of a
  typical 10 MB video). Plans with 20 TB included exist around EUR 4–5 per
  month at budget cloud providers in their EU locations.
- Same continent as the main VPS to keep latency low.
- Software: Squid (or tinyproxy) with a username and password, listening on
  one port, and a firewall rule that only accepts the main VPS's IP.

Avoid per-GB "residential" proxy plans for this: video traffic makes them cost
far more per month than a VPS.
