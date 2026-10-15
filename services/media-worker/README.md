# Media delivery Worker

Serves recordings and cached creator avatars from the R2 bucket. It reads them
through a Worker **R2 binding** instead of the S3 API endpoint
(`<account>.r2.cloudflarestorage.com`). That endpoint answered 503 to range
requests during playback and to downloads.

**Where it runs (option 1 of `docs/decisions/media-worker-options.md`).** The
bucket lives in a different Cloudflare account from `savestream.online`, and an
R2 binding only works inside the bucket's own account. So the Worker is
deployed to that account and served at
`https://savestream-media.<subdomain>.workers.dev`. The Cache API does nothing on
workers.dev, so `EDGE_CACHE` is `off`. The Worker then skips cache lookups and
the background full-object reads that would fill the cache. If the domain later
moves to the R2 account, add a custom domain route and set `EDGE_CACHE` back on.

| Path | Access | Cache |
|---|---|---|
| `/o/<key>?e=&cd=&s=` | Signed by the API: HMAC-SHA256 over path, expiry and Content-Disposition. Expired or edited links get 403. | Streamed from the R2 binding (edge cache for files ≤ 256 MB only when `EDGE_CACHE` is on). Browser: `private` until expiry. |
| `/a/<32-hex id>` | Public, like `/v1/public/creator-avatars/<id>`. Raster image types only. | Browser, 1 day (plus edge when `EDGE_CACHE` is on). |
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

All steps are **Actions → Deploy Media**, which picks a `mode`:

1. **Secrets** (set by the owner): `CLOUDFLARE_MEDIA_ACCOUNT_ID` (the account that owns the R2 bucket) and `CLOUDFLARE_MEDIA_API_TOKEN`. The token needs **Account › Workers Scripts: Edit** and **Account › Workers R2 Storage: Read** on that account.
2. **Signing secret.** Deploy Backend creates `media_signing_secret` in the VPS secrets dir. It is created once and never printed.
3. **`check`** changes nothing. It verifies:
   - the token is active;
   - Workers Scripts are reachable;
   - the bucket from `production.env` belongs to this account and is readable;
   - the account has a workers.dev subdomain.

   It prints the media origin.
4. **`deploy`** runs the check, then:
   - deploys the Worker and sets its `MEDIA_SIGNING_SECRET`;
   - smoke-tests `/healthz`, a real avatar, a signed range request (`206 video/mp4`), a bad signature (`403`) and CORS.

   The backend is not changed.
5. **`enable`** does `deploy`, then:
   - sets `SAVESTREAM_MEDIA_BASE_URL=<media origin>` in `production.env`, keeping a timestamped copy of the old file;
   - restarts the API services;
   - rolls the recorder over with `recorder-rollout.sh`, a drain: running recordings finish on the old container.

   Avatar links switch at the next avatar refresh, within 10 minutes.
6. **Rollback: `disable`.** Removes the variable and restarts and drains the same way. Links go back to the S3 endpoint at once. The Worker keeps running, so links already handed out stay valid until they expire.
