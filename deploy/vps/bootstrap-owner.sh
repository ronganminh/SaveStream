#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="deploy/vps/production.env"
COMPOSE_FILE="deploy/vps/docker-compose.production.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Run production setup first." >&2
  exit 1
fi

email="${1:-owner@savestream.online}"

read -r -s -p "Temporary password for $email: " password
printf '\n'
read -r -s -p "Confirm password: " confirm
printf '\n'

if [[ "$password" != "$confirm" ]]; then
  echo "Passwords do not match." >&2
  exit 1
fi

if (( ${#password} < 8 )); then
  echo "Password must be at least 8 characters." >&2
  exit 1
fi

PY_CODE="$(cat <<'PY'
import asyncio
import sys
from datetime import datetime, timezone

from sqlalchemy import select, update

from app.infrastructure.db.models import AuthSession, PasswordCredential, User
from app.infrastructure.db.session import Database
from app.infrastructure.security.passwords import PasswordService
from app.settings import get_app_settings

ADMIN_ROLES = {"admin", "owner", "support", "finance"}


async def main() -> None:
    email = sys.stdin.readline().rstrip("\n").strip()
    password = sys.stdin.readline().rstrip("\n")
    if not email:
        raise SystemExit("Email is required")

    normalized = email.casefold()
    password_hash = PasswordService().hash(password)
    now = datetime.now(timezone.utc)

    database = Database(get_app_settings().database_url)
    try:
        async with database.session() as session:
            admins = (
                await session.scalars(
                    select(User).where(User.role.in_(ADMIN_ROLES))
                )
            ).all()
            target = await session.scalar(
                select(User).where(User.normalized_email == normalized)
            )

            if admins and all(
                target is None or admin.id != target.id for admin in admins
            ):
                raise SystemExit(
                    "Refusing bootstrap: another admin account already exists."
                )

            if target is not None and target.role in ADMIN_ROLES:
                print(
                    f"ADMIN_ALREADY_EXISTS email={target.email} role={target.role}"
                )
                return

            if target is None:
                target = User(
                    email=email,
                    normalized_email=normalized,
                    display_name="SaveStream Owner",
                    locale="en",
                    # Current production image understands the legacy admin role.
                    # D0 migration converts it to owner; newer code keeps admin as
                    # an owner-equivalent compatibility alias.
                    role="admin",
                    email_verified_at=now,
                    is_active=True,
                )
                session.add(target)
                await session.flush()
                session.add(
                    PasswordCredential(
                        user_id=target.id,
                        password_hash=password_hash,
                    )
                )
                action = "CREATED"
            else:
                target.role = "admin"
                target.is_active = True
                target.email_verified_at = target.email_verified_at or now
                credential = await session.get(PasswordCredential, target.id)
                if credential is None:
                    session.add(
                        PasswordCredential(
                            user_id=target.id,
                            password_hash=password_hash,
                        )
                    )
                else:
                    credential.password_hash = password_hash
                    credential.password_changed_at = now

                await session.execute(
                    update(AuthSession)
                    .where(
                        AuthSession.user_id == target.id,
                        AuthSession.revoked_at.is_(None),
                    )
                    .values(
                        revoked_at=now,
                        revoked_reason="initial_admin_bootstrap",
                    )
                )
                action = "PROMOTED"

            await session.commit()
            print(
                f"BOOTSTRAP_OK action={action} email={target.email} "
                f"role={target.role} user_id={target.id}"
            )
    finally:
        await database.close()


asyncio.run(main())
PY
)"

compose=(
  docker compose
  --env-file "$ENV_FILE"
  -f "$COMPOSE_FILE"
)

printf '%s\n%s\n' "$email" "$password" |
  "${compose[@]}" exec -T api python -c "$PY_CODE"

unset password confirm
echo "Next: sign in at https://savestream.online and open /admin."
echo "After Track D is deployed, complete the required TOTP setup on first admin access."
