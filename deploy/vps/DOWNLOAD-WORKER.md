# Separate TikTok download worker

Do not run the downloader on the LIVE/recorder host. Deploy this compose file on a separate machine with the command:
\`docker compose -f deploy/vps/docker-compose.download-worker.yml up -d --build\`

## Required configuration on the downloader host

Set these non-secret variables:

- \`SAVESTREAM_R2_ENDPOINT\`: the account's R2 S3 endpoint.
- \`SAVESTREAM_DOWNLOAD_R2_BUCKET\`: a dedicated bucket used only for temporary downloads.
- \`SAVESTREAM_SECRETS_DIR\`: directory containing the four secret files below.

Create these secret files with restrictive permissions:

- \`celery_broker_url\`: a dedicated Redis ACL user/URL for the downloader (not the API's unrestricted credential), limited to the downloads queue and required Celery transport keys/commands, reachable over a private VPN/tunnel only.
- \`celery_result_backend\`: a dedicated Redis ACL user/URL limited to the Celery result keys required for download job IDs, reachable over a private VPN/tunnel only.
- \`download_r2_access_key\` and \`download_r2_secret_key\`: a separate R2 token scoped only to the dedicated download bucket.

Do not copy the production database URL, JWT secret, payment credentials, SMTP credentials, metrics token, FCM key, or Google Play service-account key to this host. Do not expose Redis publicly; connect the two hosts through a private network and restrict the Redis firewall/ACL to the API and downloader.

## R2 retention

Apply \`deploy/vps/downloads-r2-lifecycle.json\` to the dedicated bucket using Cloudflare's R2 lifecycle controls (Dashboard or Wrangler). The rule expires \`downloads/*\` after one day. The worker also queues an object-delete task 24 hours after upload; the R2 lifecycle rule is the durable backstop if the queue is unavailable.

The download worker has CPU, memory, process-count, shared-memory and temporary-filesystem limits. Chromium is installed only in \`backend/Dockerfile.downloader\`; the shared API/recorder image no longer installs Chromium.

## Important

The separate worker will not consume jobs until the API's Celery broker URL is reachable from this host over the private network. The R2 bucket and lifecycle rule must exist before enabling downloads. This file is deployment configuration only; it does not deploy or start a production server by itself.
