#!/bin/sh
set -eu
umask 077

SECRETS_DIR="${SAVESTREAM_SECRETS_DIR:-$HOME/savestream-secrets/production}"
ENV_FILE="$HOME/SaveStream/deploy/vps/production.env"
mkdir -p "$SECRETS_DIR"

random_hex() {
  openssl rand -hex 32
}

hidden_read() {
  prompt="$1"
  printf '%s' "$prompt"
  stty -echo
  IFS= read -r value
  stty echo
  printf '\n'
  printf '%s' "$value"
}

restore_tty() {
  stty echo 2>/dev/null || true
}
trap restore_tty EXIT INT TERM HUP

printf 'Cloudflare R2 S3 endpoint: '
IFS= read -r R2_ENDPOINT
printf 'Cloudflare R2 bucket: '
IFS= read -r R2_BUCKET
printf 'Cloudflare R2 Access Key ID: '
IFS= read -r R2_ACCESS_KEY
R2_SECRET_KEY="$(hidden_read 'Cloudflare R2 Secret Access Key: ')"

printf 'Brevo SMTP login: '
IFS= read -r SMTP_USERNAME
SMTP_PASSWORD="$(hidden_read 'Brevo SMTP key: ')"

PAYMENT_API_KEY="$(hidden_read 'Lemon Squeezy LIVE API key: ')"
PAYMENT_WEBHOOK_SECRET="$(hidden_read 'Lemon Squeezy LIVE webhook secret: ')"
printf 'Lemon Squeezy LIVE Store ID: '
IFS= read -r LEMON_STORE_ID
printf 'Lemon Squeezy LIVE Variant ID: '
IFS= read -r LEMON_VARIANT_ID

printf 'Operations alert email: '
IFS= read -r OPS_ALERT_EMAIL
printf 'Trusted proxy CIDRs (for example 172.16.0.0/12): '
IFS= read -r TRUSTED_PROXY_CIDRS

case "$R2_ENDPOINT" in
  https://*) ;;
  *)
    printf '%s\n' 'Production R2/S3 endpoint must use HTTPS.' >&2
    exit 2
    ;;
esac

[ -n "$R2_BUCKET" ] || { echo 'R2 bucket is required.' >&2; exit 2; }
[ -n "$R2_ACCESS_KEY" ] || { echo 'R2 access key is required.' >&2; exit 2; }
[ -n "$R2_SECRET_KEY" ] || { echo 'R2 secret key is required.' >&2; exit 2; }
[ -n "$SMTP_USERNAME" ] || { echo 'Brevo SMTP login is required.' >&2; exit 2; }
[ -n "$SMTP_PASSWORD" ] || { echo 'Brevo SMTP key is required.' >&2; exit 2; }
[ -n "$PAYMENT_API_KEY" ] || { echo 'Lemon Squeezy LIVE API key is required.' >&2; exit 2; }
WEBHOOK_LEN="${#PAYMENT_WEBHOOK_SECRET}"
[ "$WEBHOOK_LEN" -ge 6 ] && [ "$WEBHOOK_LEN" -le 40 ] || {
  echo 'Lemon Squeezy webhook secret must be 6 to 40 characters.' >&2
  exit 2
}
[ -n "$LEMON_STORE_ID" ] || { echo 'Lemon Squeezy LIVE Store ID is required.' >&2; exit 2; }
[ -n "$LEMON_VARIANT_ID" ] || { echo 'Lemon Squeezy LIVE Variant ID is required.' >&2; exit 2; }
[ -n "$OPS_ALERT_EMAIL" ] || { echo 'Operations alert email is required.' >&2; exit 2; }
[ -n "$TRUSTED_PROXY_CIDRS" ] || { echo 'Trusted proxy CIDRs are required.' >&2; exit 2; }

POSTGRES_PASSWORD="$(random_hex)"
REDIS_PASSWORD="$(random_hex)"
JWT_SECRET="$(random_hex)"
METRICS_TOKEN="$(random_hex)"

write_secret() {
  name="$1"
  value="$2"
  printf '%s\n' "$value" > "$SECRETS_DIR/$name"
  chmod 600 "$SECRETS_DIR/$name"
}

write_secret postgres_password "$POSTGRES_PASSWORD"
write_secret database_url "postgresql+asyncpg://savestream:$POSTGRES_PASSWORD@postgres:5432/savestream"
write_secret redis_password "$REDIS_PASSWORD"
write_secret redis_url "redis://:$REDIS_PASSWORD@redis:6379/0"
write_secret celery_broker_url "redis://:$REDIS_PASSWORD@redis:6379/1"
write_secret celery_result_backend "redis://:$REDIS_PASSWORD@redis:6379/2"
write_secret r2_access_key "$R2_ACCESS_KEY"
write_secret r2_secret_key "$R2_SECRET_KEY"
write_secret jwt_secret "$JWT_SECRET"
write_secret smtp_username "$SMTP_USERNAME"
write_secret smtp_password "$SMTP_PASSWORD"
write_secret payment_api_key "$PAYMENT_API_KEY"
write_secret payment_webhook_secret "$PAYMENT_WEBHOOK_SECRET"
write_secret metrics_token "$METRICS_TOKEN"

cat > "$ENV_FILE" <<EOF
SAVESTREAM_SECRETS_DIR=$SECRETS_DIR
SAVESTREAM_API_BIND_PORT=18001
SAVESTREAM_PUBLIC_API_ORIGIN=https://api.savestream.online
SAVESTREAM_FRONTEND_ORIGIN=https://savestream.online
SAVESTREAM_CORS_ALLOW_ORIGINS=https://savestream.online,https://www.savestream.online
SAVESTREAM_R2_ENDPOINT=$R2_ENDPOINT
SAVESTREAM_R2_BUCKET=$R2_BUCKET
SAVESTREAM_LEMON_SQUEEZY_STORE_ID=$LEMON_STORE_ID
SAVESTREAM_LEMON_SQUEEZY_VARIANT_ID=$LEMON_VARIANT_ID
SAVESTREAM_OPS_ALERT_EMAIL=$OPS_ALERT_EMAIL
SAVESTREAM_TRUSTED_PROXY_CIDRS=$TRUSTED_PROXY_CIDRS
EOF
chmod 600 "$ENV_FILE"

printf 'Production secrets written to %s\n' "$SECRETS_DIR"
printf 'Production environment written to %s\n' "$ENV_FILE"
printf '%s\n' 'No secret values were printed.'
