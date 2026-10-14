# Automated production deploy

Two GitHub Actions workflows deploy production. Secrets stay in GitHub; a
Claude session (or a person) only triggers the workflow.

| Workflow | What it does |
| --- | --- |
| `Deploy Backend` (`.github/workflows/deploy-backend.yml`) | SSH to the VPS, check the checkout is a clean `main`, `git pull --ff-only`, then `deploy/vps/deploy.sh`: refuse while recordings are running, `pg_dump` backup to `backups/`, `compose config`, `up -d --build`, wait for api health (api runs `alembic upgrade head`), `alembic current`, health and admin CORS checks. |
| `Deploy Web` (`.github/workflows/deploy-web.yml`) | Write `apps/web/.env.production` from a secret, refuse a non-production env (prevents Demo mode), typecheck, build, `wrangler deploy`, smoke-check savestream.online. |

Both run on demand (Actions → workflow → Run workflow). Each one also runs
automatically after its CI passes on `main` once the repository variable
`AUTO_DEPLOY_BACKEND` / `AUTO_DEPLOY_WEB` is set to `true`.

## One-time setup

### 1. VPS deploy key

On your own computer:

```bash
ssh-keygen -t ed25519 -N "" -C "github-deploy-savestream" -f savestream_deploy
ssh-copy-id -i savestream_deploy.pub savestream-vps   # or append it to ~/.ssh/authorized_keys on the VPS
ssh-keyscan -p 22 <VPS_HOST> > known_hosts.txt
```

The SSH user must be able to run `docker compose` and `git pull` in
`/home/nduythanh/SaveStream`.

### 2. Cloudflare API token

Cloudflare dashboard → My Profile → API Tokens → Create Token → template
**Edit Cloudflare Workers**, scoped to the SaveStream account. Note the
Account ID shown on the Workers overview page.

### 3. GitHub secrets and variables

Repository → Settings → Secrets and variables → Actions (or an environment
named `production`, which can also require an approver):

| Secret | Value |
| --- | --- |
| `VPS_HOST` | VPS hostname or IP |
| `VPS_USER` | SSH user, e.g. `nduythanh` |
| `VPS_SSH_KEY` | contents of `savestream_deploy` (private key) |
| `VPS_KNOWN_HOSTS` | contents of `known_hosts.txt` |
| `CLOUDFLARE_API_TOKEN` | token from step 2 |
| `CLOUDFLARE_ACCOUNT_ID` | account id from step 2 |
| `WEB_ENV_PRODUCTION` | full contents of the working `apps/web/.env.production` |

| Variable (optional) | Default |
| --- | --- |
| `VPS_PORT` | `22` |
| `VPS_APP_DIR` | `/home/nduythanh/SaveStream` |
| `AUTO_DEPLOY_BACKEND` | unset (manual only) |
| `AUTO_DEPLOY_WEB` | unset (manual only) |

Delete the local `savestream_deploy` files after saving the secret.

## Safety

- The backend deploy aborts if tracked files on the VPS were edited, if the
  pull is not a fast-forward, or while cloud recordings are running (the
  `allow_active_recordings` input overrides this).
- Every backend deploy writes `backups/predeploy-<time>-<sha>.dump` unless
  `skip_backup` is ticked.
- `docker compose down -v` is never run.
- Rollback: revert the commit on `main` and run the workflow again; restore a
  database dump only if a migration damaged data.
