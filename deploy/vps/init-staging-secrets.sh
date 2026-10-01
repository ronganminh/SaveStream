#!/bin/sh
set -eu
umask 077

SECRETS_DIR="${SAVESTREAM_SECRETS_DIR:-$HOME/savestream-secrets/staging}"
ENV_FILE="$HOME/SaveStream/deploy/vps/staging.env"
mkdir -p "$SECRETS_DIR"

random_hex() {
  openssl rand -hex 32
}

POSTGRES_PASSWORD="$(random_hex)"
REDIS_PASSWORD="$(random_hex)"
JWT_SECRET="$(random_hex)"
PAYMENT_WEBHOOK_SECRET="$(random_hex)"
METRICS_TOKEN="$(random_hex)"

printf 'Cloudflare R2 S3 endpoint: '
IFS= read -r R2_ENDPOINT
printf 'Cloudflare R2 bucket: '
IFS= read -r R2_BUCKET
printf 'Cloudflare R2 Access Key ID: '
IFS= read -r R2_ACCESS_KEY

restore_tty() {
  stty echo 2>/dev/null || true
}
trap restore_tty EXIT INT TERM HUP

printf 'Cloudflare R2 Secret Access Key: '
stty -echo
IFS= read -r R2_SECRET_KEY
stty echo
printf '\n'

case "$R2_ENDPOINT" in
  https://*.r2.cloudflarestorage.com) ;;
  *)
    printf '%s\n' 'R2 endpoint must be the Cloudflare HTTPS S3 endpoint.' >&2
    exit 2
    ;;
esac

[ -n "$R2_BUCKET" ] || { echo 'R2 bucket is required.' >&2; exit 2; }
[ -n "$R2_ACCESS_KEY" ] || { echo 'R2 access key is required.' >&2; exit 2; }
[ -n "$R2_SECRET_KEY" ] || { echo 'R2 secret key is required.' >&2; exit 2; }

write_secret() {
  name="$1"
  value="$2"
  printf '%s\n' "$value" > "$SECRETS_DIR/$name"
  chmod 600 "$SECRETS_DIR/$name"
}

write_secret postgres_password "$POSTGRES_PASSWORD"
write_secret database_url "postgresql+asyncpg://savestream:$POSTGRES_PASSWORD@postgres:5432/savestream_staging"
write_secret redis_password "$REDIS_PASSWORD"
write_secret redis_url "redis://:$REDIS_PASSWORD@redis:6379/0"
write_secret celery_broker_url "redis://:$REDIS_PASSWORD@redis:6379/1"
write_secret celery_result_backend "redis://:$REDIS_PASSWORD@redis:6379/2"
write_secret r2_access_key "$R2_ACCESS_KEY"
write_secret r2_secret_key "$R2_SECRET_KEY"
write_secret jwt_secret "$JWT_SECRET"
write_secret payment_webhook_secret "$PAYMENT_WEBHOOK_SECRET"
write_secret metrics_token "$METRICS_TOKEN"

cat > "$ENV_FILE" <<EOF
SAVESTREAM_SECRETS_DIR=$SECRETS_DIR
SAVESTREAM_R2_ENDPOINT=$R2_ENDPOINT
SAVESTREAM_R2_BUCKET=$R2_BUCKET
EOF
chmod 600 "$ENV_FILE"

printf 'Secrets written to %s\n' "$SECRETS_DIR"
printf 'Environment file written to %s\n' "$ENV_FILE"
printf '%s\n' 'Do not paste the secret files into chat.'
