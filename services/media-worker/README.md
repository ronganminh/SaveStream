# Media delivery Worker (`media.savestream.online`)

Serves recordings and cached creator avatars from the R2 bucket. It reads them
through a Worker **R2 binding** instead of the S3 API endpoint
(`<account>.r2.cloudflarestorage.com`). That endpoint answered 503 to range
requests during playback and to downloads. Responses go through Cloudflare's
**edge cache** where possible.

| Path | Access | Cache |
|---|---|---|
| `/o/<key>?e=&cd=&s=` | Signed by the API: HMAC-SHA256 over path, expiry and Content-Disposition. Expired or edited links get 403. | Edge cache for files ≤ 256 MB. Larger files are streamed from the R2 binding. Browser: `private` until expiry. |
| `/a/<32-hex id>` | Public, like `/v1/public/creator-avatars/<id>`. Raster image types only. | Edge + browser, 1 day. |
| `/healthz` | Public | none |

- **Range requests** return `206` from the cached object or from R2. `416` is returned for unsatisfiable ranges.
- **Transient R2 errors** are retried (3 attempts). If they persist, the Worker returns `502` with `Retry-After`, so a request never hangs.
- **Downloads.** The API signs `Content-Disposition: attachment; filename="…"` into the link, so the file name cannot be changed.
- **Cache.** Entries are keyed by object only, without the signature, so every viewer of a file shares one cache entry. Clients reach the cache only through a valid signature.
- **Deletions.** Once a recording is deleted, the API stops issuing links for it. A cached copy stays until its TTL (1 day) but cannot be reached.

## Code

- `src/index.js` — the Worker, plain JavaScript with no dependencies.
- `test/` — unit tests (`npm --workspace services/media-worker test`).
- Backend side:
  - `backend/src/app/infrastructure/storage/media_urls.py` signs the links.
  - `MinioStorageClient.presigned_get_url` uses it when `SAVESTREAM_MEDIA_BASE_URL` and the signing secret are both set.
  - Avatar URLs switch at the next avatar refresh, within 10 minutes.

## Deploy

1. **Cloudflare API token** (`CLOUDFLARE_API_TOKEN`) needs these permissions, besides Workers Scripts: Edit:
   - **Workers R2 Storage: Read**, for the bucket binding;
   - **Zone → Workers Routes: Edit** and **DNS: Edit** on `savestream.online`, for the `media.savestream.online` custom domain.
2. **Deploy Backend** (any release with this change) creates the signing secret `media_signing_secret` in the VPS secrets dir. It is created once and never printed.
3. **Actions → Deploy Media → mode `deploy`**. The workflow:
   - reads the bucket name and secret from the VPS;
   - deploys the Worker and sets its `MEDIA_SIGNING_SECRET`;
   - smoke-tests a real avatar, a signed range request (`206 video/mp4`) and a bad signature (`403`).
4. **Deploy Media → mode `enable`.** This sets `SAVESTREAM_MEDIA_BASE_URL=https://media.savestream.online` in `production.env` and restarts the API services. The recorder is not touched, so running recordings continue.
5. **Rollback:** Deploy Media → mode `disable`. Links go back to the S3 endpoint at once.
