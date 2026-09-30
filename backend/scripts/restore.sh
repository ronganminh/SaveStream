#!/bin/sh
set -eu

: "${SAVESTREAM_RESTORE_CONFIRM:?set SAVESTREAM_RESTORE_CONFIRM=YES}"
[ "$SAVESTREAM_RESTORE_CONFIRM" = "YES" ] || {
  echo "restore refused: SAVESTREAM_RESTORE_CONFIRM must equal YES" >&2
  exit 2
}
: "${SAVESTREAM_RESTORE_DATABASE_URL:?set SAVESTREAM_RESTORE_DATABASE_URL}"
: "${SAVESTREAM_RESTORE_MINIO_ALIAS:?set SAVESTREAM_RESTORE_MINIO_ALIAS}"
: "${SAVESTREAM_MINIO_BUCKET:?set SAVESTREAM_MINIO_BUCKET}"
: "${1:?usage: restore.sh <backup-directory>}"

BACKUP_DIR="$1"
test -f "$BACKUP_DIR/postgres.dump"
test -f "$BACKUP_DIR/SHA256SUMS"

command -v pg_restore >/dev/null 2>&1
command -v mc >/dev/null 2>&1
command -v sha256sum >/dev/null 2>&1

(
  cd "$BACKUP_DIR"
  sha256sum -c SHA256SUMS
)
pg_restore --clean --if-exists --no-owner --dbname "$SAVESTREAM_RESTORE_DATABASE_URL" "$BACKUP_DIR/postgres.dump"
mc mirror --overwrite --remove "$BACKUP_DIR/minio" "$SAVESTREAM_RESTORE_MINIO_ALIAS/$SAVESTREAM_MINIO_BUCKET"
