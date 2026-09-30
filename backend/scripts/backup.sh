#!/bin/sh
set -eu

: "${SAVESTREAM_POSTGRES_BACKUP_URL:?set SAVESTREAM_POSTGRES_BACKUP_URL}"
: "${SAVESTREAM_MINIO_ALIAS:?set SAVESTREAM_MINIO_ALIAS}"
: "${SAVESTREAM_MINIO_BUCKET:?set SAVESTREAM_MINIO_BUCKET}"

BACKUP_ROOT="${SAVESTREAM_BACKUP_DIR:-./backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$BACKUP_ROOT/$STAMP"

command -v pg_dump >/dev/null 2>&1
command -v mc >/dev/null 2>&1
command -v sha256sum >/dev/null 2>&1

mkdir -p "$DEST/minio"
pg_dump --format=custom --no-owner --file "$DEST/postgres.dump" "$SAVESTREAM_POSTGRES_BACKUP_URL"
mc mirror --overwrite "$SAVESTREAM_MINIO_ALIAS/$SAVESTREAM_MINIO_BUCKET" "$DEST/minio"
(
  cd "$DEST"
  find . -type f ! -name SHA256SUMS -print | sort | xargs sha256sum > SHA256SUMS
)
printf '%s\n' "$DEST"
