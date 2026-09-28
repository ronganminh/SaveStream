# SaveStream

SaveStream is a cloud SaaS for automatically monitoring TikTok channels, recording livestreams on server infrastructure, processing the completed video, and making it available for playback and download.

## Product lifecycle

`Added → Waiting for live → Recording → Processing → Ready`

## Repository plan

- `apps/web` — React + TypeScript frontend based on the approved Lovable prototype
- `apps/api` — FastAPI application
- `services/monitor-worker` — TikTok live-status monitoring
- `services/recording-worker` — stream recording
- `services/processing-worker` — FFmpeg processing and storage upload
- `packages/tiktok-engine` — reusable TikTok recording engine
- `infra` — Docker and deployment configuration
- `docs` — product and engineering documentation

The initial implementation is frontend-first. Backend and worker services will be added in later phases.
