# SaveStream

SaveStream is a cloud SaaS for automatically monitoring TikTok channels, recording livestreams on server infrastructure, processing the completed video, and making it available for playback and download.

## Product lifecycle

`Added → Waiting for live → Recording → Processing → Ready`

## Repository structure

- `apps/web` — approved frontend prototype, implemented with React, TypeScript, TanStack Router and Tailwind CSS
- `apps/api` — FastAPI service (next phase)
- `services/monitor-worker` — TikTok live-status monitoring (next phase)
- `services/recording-worker` — cloud stream recording (next phase)
- `services/processing-worker` — FFmpeg processing and object-storage upload (next phase)
- `packages/tiktok-engine` — reusable TikTok recording engine (next phase)
- `infra` — Docker and deployment configuration
- `docs` — product and engineering documentation

## Local frontend development

```bash
npm install
npm run dev
```

The frontend currently uses typed mock data. No authentication, TikTok API, recording worker, storage, billing or database behavior is real yet.
