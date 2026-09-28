# SaveStream architecture

## Planned stack

- Web: React, TypeScript, TanStack Router, Tailwind CSS
- API: FastAPI
- Database: PostgreSQL
- Queue and locks: Redis
- Workers: Python services in Docker
- Recording and processing: curl-cffi + FFmpeg
- Video storage: Cloudflare R2 or an S3-compatible service
- Billing: Stripe
- Monitoring: Sentry, Prometheus and Grafana

## Planned runtime flow

1. The API stores a monitored TikTok channel.
2. The monitor worker periodically checks its live status.
3. A distributed lock prevents duplicate recording jobs.
4. A recording worker resolves the stream URL and writes a temporary source file.
5. The processing worker remuxes or transcodes the recording with FFmpeg.
6. The final video is uploaded to object storage.
7. Recording metadata and quota usage are updated in PostgreSQL.
8. The web application reads status and recording data through the API.

## Security boundary

The frontend never receives TikTok cookies, object-storage credentials, worker secrets or Stripe secret keys. Signed URLs and short-lived download access will be issued by the API.
