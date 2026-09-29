# SaveStream Backend

Phase 0 baseline for migrating the existing TikTok recorder CLI into the SaveStream backend. The recorder behavior is intentionally kept intact while the repository gains reproducible dependencies, safety checks, tests, typed configuration, structured logging, HTTP timeouts, and CI.

## Phase 0 guarantees

- Existing `src/main.py` CLI remains the entry point.
- Runtime code never installs Python or system packages automatically.
- Dependencies are declared in `pyproject.toml` and pinned in `requirements.lock`.
- Environment settings use typed immutable configuration.
- Logs are JSON by default with credential/token redaction.
- TikTok requests, stream requests, proxy checks and updater downloads have explicit timeouts.
- Sanitized TikTok fixtures and characterization tests protect current behavior before engine refactoring.
- CI runs lint, incremental type checking, tests and CLI smoke checks.

## Local setup

```bash
cd backend
python -m venv .venv
. .venv/bin/activate
python -m pip install --no-deps -r requirements.lock
python -m pip install --no-deps --no-build-isolation -e .
cp src/cookies.example.json src/cookies.json
python src/main.py -h
```

## Quality gates

```bash
ruff check src tests
mypy src/config.py src/http_utils/http_client.py src/utils/logger_manager.py src/utils/dependencies.py
pytest
python src/main.py -h
```

Phase 0 does not add FastAPI, PostgreSQL, Redis/Celery, storage, auth, credits or billing. Those remain later migration phases.
