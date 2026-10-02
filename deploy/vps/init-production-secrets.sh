#!/bin/sh
# Provision production secrets and deploy/vps/production.env.
#
# Safe to re-run: existing secret files are kept, generated passwords/JWT are
# never rotated, and an existing production.env is backed up before rewrite.
# Never prints secret values.
set -eu
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/production.env"
SECRETS_DIR="${SAVESTREAM_SECRETS_DIR:-$HOME/savestream-secrets/production}"
PLACEHOLDER=payments-disabled
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

restore_tty() {
  stty echo 2>/dev/null || true
}
trap restore_tty EXIT INT TERM HUP

env_default() {
  key="$1"
  fallback="$2"
  value=""
  if [ -f "$ENV_FILE" ]; then
    value="$(awk -F= -v k="$key" '$1==k {sub($1"=",""); print; exit}' "$ENV_FILE")"
  fi
  printf '%s' "${value:-$fallback}"
}

ask() {
  prompt="$1"
  default="$2"
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r value
  printf '%s' "${value:-$default}"
}

hidden_read() {
  printf '%s' "$1" >&2
  stty -echo 2>/dev/null || true
  IFS= read -r value
  stty echo 2>/dev/null || true
  printf '\n' >&2
  printf '%s' "$value"
}

has_secret() {
  [ -s "$SECRETS_DIR/$1" ]
}

write_secret() {
  printf '%s\n' "$2" > "$SECRETS_DIR/$1"
  chmod 600 "$SECRETS_DIR/$1"
}

# Prompt only when the secret file is missing or empty.
ensure_prompted() {
  name="$1"
  prompt="$2"
  hidden="$3"
  if has_secret "$name"; then
    printf 'keep    %s\n' "$name" >&2
    return
  fi
  if [ "$hidden" = hidden ]; then
    value="$(hidden_read "$prompt: ")"
  else
    value="$(ask "$prompt" "")"
  fi
  [ -n "$value" ] || { echo "$prompt is required." >&2; exit 2; }
  write_secret "$name" "$value"
  printf 'created %s\n' "$name" >&2
}

ensure_random() {
  if has_secret "$1"; then
    printf 'keep    %s\n' "$1" >&2
  else
    write_secret "$1" "$(openssl rand -hex 32)"
    printf 'created %s\n' "$1" >&2
  fi
}

R2_ENDPOINT="$(ask 'Cloudflare R2 S3 endpoint' "$(env_default SAVESTREAM_R2_ENDPOINT '')")"
R2_BUCKET="$(ask 'Cloudflare R2 bucket' "$(env_default SAVESTREAM_R2_BUCKET '')")"
OPS_ALERT_EMAIL="$(ask 'Operations alert email' "$(env_default SAVESTREAM_OPS_ALERT_EMAIL '')")"
TRUSTED_PROXY_CIDRS="$(ask 'Trusted proxy CIDRs' "$(env_default SAVESTREAM_TRUSTED_PROXY_CIDRS 172.16.0.0/12)")"

case "$R2_ENDPOINT" in
  https://*) ;;
  *) echo 'Production R2/S3 endpoint must use HTTPS.' >&2; exit 2 ;;
esac
[ -n "$R2_BUCKET" ] || { echo 'R2 bucket is required.' >&2; exit 2; }
[ -n "$OPS_ALERT_EMAIL" ] || { echo 'Operations alert email is required.' >&2; exit 2; }
[ -n "$TRUSTED_PROXY_CIDRS" ] || { echo 'Trusted proxy CIDRs are required.' >&2; exit 2; }

ensure_prompted r2_access_key 'Cloudflare R2 Access Key ID' visible
ensure_prompted r2_secret_key 'Cloudflare R2 Secret Access Key' hidden
ensure_prompted smtp_username 'Brevo SMTP login' visible
ensure_prompted smtp_password 'Brevo SMTP key' hidden

ensure_random postgres_password
ensure_random redis_password
ensure_random jwt_secret
ensure_random metrics_token

PAYMENT_PROVIDER="$(ask 'Payment provider (disabled or lemonsqueezy)' "$(env_default SAVESTREAM_PAYMENT_PROVIDER disabled)")"
LEMON_STORE_ID=""
LEMON_VARIANT_ID=""
case "$PAYMENT_PROVIDER" in
  disabled)
    # Compose mounts these files in every mode; keep real keys if present.
    for name in payment_api_key payment_webhook_secret; do
      if has_secret "$name"; then
        printf 'keep    %s\n' "$name" >&2
      else
        write_secret "$name" "$PLACEHOLDER"
        printf 'created %s (placeholder)\n' "$name" >&2
      fi
    done
    ;;
  lemonsqueezy)
    for name in payment_api_key payment_webhook_secret; do
      if has_secret "$name" && [ "$(cat "$SECRETS_DIR/$name")" = "$PLACEHOLDER" ]; then
        rm -f "$SECRETS_DIR/$name"
      fi
    done
    ensure_prompted payment_api_key 'Lemon Squeezy LIVE API key' hidden
    ensure_prompted payment_webhook_secret 'Lemon Squeezy LIVE webhook secret' hidden
    WEBHOOK_LEN="$(tr -d '\n' < "$SECRETS_DIR/payment_webhook_secret" | wc -c | tr -d ' ')"
    [ "$WEBHOOK_LEN" -ge 6 ] && [ "$WEBHOOK_LEN" -le 40 ] || {
      echo 'Lemon Squeezy webhook secret must be 6 to 40 characters.' >&2
      exit 2
    }
    LEMON_STORE_ID="$(ask 'Lemon Squeezy LIVE Store ID' "$(env_default SAVESTREAM_LEMON_SQUEEZY_STORE_ID '')")"
    LEMON_VARIANT_ID="$(ask 'Lemon Squeezy LIVE Variant ID' "$(env_default SAVESTREAM_LEMON_SQUEEZY_VARIANT_ID '')")"
    [ -n "$LEMON_STORE_ID" ] || { echo 'Lemon Squeezy LIVE Store ID is required.' >&2; exit 2; }
    [ -n "$LEMON_VARIANT_ID" ] || { echo 'Lemon Squeezy LIVE Variant ID is required.' >&2; exit 2; }
    ;;
  *)
    echo 'Payment provider must be disabled or lemonsqueezy.' >&2
    exit 2
    ;;
esac

# Connection URLs are derived from the kept passwords and match the compose
# service names and the "savestream" database.
POSTGRES_PASSWORD="$(cat "$SECRETS_DIR/postgres_password")"
REDIS_PASSWORD="$(cat "$SECRETS_DIR/redis_password")"
write_secret database_url "postgresql+asyncpg://savestream:$POSTGRES_PASSWORD@postgres:5432/savestream"
write_secret redis_url "redis://:$REDIS_PASSWORD@redis:6379/0"
write_secret celery_broker_url "redis://:$REDIS_PASSWORD@redis:6379/1"
write_secret celery_result_backend "redis://:$REDIS_PASSWORD@redis:6379/2"

if [ -f "$ENV_FILE" ]; then
  BACKUP="$ENV_FILE.bak-$(date +%Y%m%d%H%M%S)"
  cp -p "$ENV_FILE" "$BACKUP"
  printf 'Previous environment backed up to %s\n' "$BACKUP"
fi

cat > "$ENV_FILE" <<EOF
SAVESTREAM_SECRETS_DIR=$SECRETS_DIR
SAVESTREAM_API_BIND_PORT=$(env_default SAVESTREAM_API_BIND_PORT 18001)
SAVESTREAM_PUBLIC_API_ORIGIN=https://api.savestream.online
SAVESTREAM_FRONTEND_ORIGIN=https://savestream.online
SAVESTREAM_CORS_ALLOW_ORIGINS=https://savestream.online,https://www.savestream.online
SAVESTREAM_R2_ENDPOINT=$R2_ENDPOINT
SAVESTREAM_R2_BUCKET=$R2_BUCKET
SAVESTREAM_PAYMENT_PROVIDER=$PAYMENT_PROVIDER
SAVESTREAM_LEMON_SQUEEZY_STORE_ID=$LEMON_STORE_ID
SAVESTREAM_LEMON_SQUEEZY_VARIANT_ID=$LEMON_VARIANT_ID
SAVESTREAM_OPS_ALERT_EMAIL=$OPS_ALERT_EMAIL
SAVESTREAM_TRUSTED_PROXY_CIDRS=$TRUSTED_PROXY_CIDRS
EOF
chmod 600 "$ENV_FILE"

printf 'Production secrets written to %s\n' "$SECRETS_DIR"
printf 'Production environment written to %s\n' "$ENV_FILE"
printf 'Payment provider: %s\n' "$PAYMENT_PROVIDER"
printf '%s\n' 'No secret values were printed.'
