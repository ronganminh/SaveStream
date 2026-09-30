#!/bin/sh
set -eu

: "${1:?usage: backup_restore_drill.sh <backup-directory>}"
BACKUP_DIR="$1"
test -f "$BACKUP_DIR/postgres.dump"
test -f "$BACKUP_DIR/SHA256SUMS"

command -v pg_restore >/dev/null 2>&1
command -v sha256sum >/dev/null 2>&1

(
  cd "$BACKUP_DIR"
  sha256sum -c SHA256SUMS
)
pg_restore --list "$BACKUP_DIR/postgres.dump" >/dev/null

if [ -n "${SAVESTREAM_DRILL_DATABASE_URL:-}" ]; then
  pg_restore --clean --if-exists --no-owner --dbname "$SAVESTREAM_DRILL_DATABASE_URL" "$BACKUP_DIR/postgres.dump"
  echo "database restore drill completed"
else
  echo "archive integrity verified; set SAVESTREAM_DRILL_DATABASE_URL for a real scratch restore"
fi
