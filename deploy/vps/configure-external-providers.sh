#!/bin/sh
set -eu
umask 077

SECRETS_DIR="${SAVESTREAM_SECRETS_DIR:-$HOME/savestream-secrets/staging}"
ENV_FILE="$HOME/SaveStream/deploy/vps/staging.external.env"
mkdir -p "$SECRETS_DIR"

restore_tty() {
  stty echo 2>/dev/null || true
}
trap restore_tty EXIT INT TERM HUP

printf 'Brevo SMTP login: '
IFS= read -r SMTP_USERNAME

printf 'Brevo SMTP key: '
stty -echo
IFS= read -r SMTP_PASSWORD
stty echo
printf '\n'

printf 'Lemon Squeezy TEST API key: '
stty -echo
IFS= read -r PAYMENT_API_KEY
stty echo
printf '\n'

printf 'Lemon Squeezy webhook signing secret: '
stty -echo
IFS= read -r PAYMENT_WEBHOOK_SECRET
stty echo
printf '\n'

printf 'Lemon Squeezy TEST Store ID: '
IFS= read -r LEMON_STORE_ID
printf 'Lemon Squeezy TEST Variant ID: '
IFS= read -r LEMON_VARIANT_ID

[ -n "$SMTP_USERNAME" ] || { echo 'Brevo SMTP login is required.' >&2; exit 2; }
[ -n "$SMTP_PASSWORD" ] || { echo 'Brevo SMTP key is required.' >&2; exit 2; }
[ -n "$PAYMENT_API_KEY" ] || { echo 'Lemon Squeezy API key is required.' >&2; exit 2; }
[ -n "$PAYMENT_WEBHOOK_SECRET" ] || { echo 'Lemon Squeezy webhook secret is required.' >&2; exit 2; }
[ -n "$LEMON_STORE_ID" ] || { echo 'Lemon Squeezy Store ID is required.' >&2; exit 2; }
[ -n "$LEMON_VARIANT_ID" ] || { echo 'Lemon Squeezy Variant ID is required.' >&2; exit 2; }

write_secret() {
  name="$1"
  value="$2"
  printf '%s\n' "$value" > "$SECRETS_DIR/$name"
  chmod 600 "$SECRETS_DIR/$name"
}

write_secret smtp_username "$SMTP_USERNAME"
write_secret smtp_password "$SMTP_PASSWORD"
write_secret payment_api_key "$PAYMENT_API_KEY"
write_secret payment_webhook_secret "$PAYMENT_WEBHOOK_SECRET"

cat > "$ENV_FILE" <<EOF
SAVESTREAM_LEMON_SQUEEZY_STORE_ID=$LEMON_STORE_ID
SAVESTREAM_LEMON_SQUEEZY_VARIANT_ID=$LEMON_VARIANT_ID
EOF
chmod 600 "$ENV_FILE"

printf 'External provider secrets written to %s\n' "$SECRETS_DIR"
printf 'External provider environment written to %s\n' "$ENV_FILE"
printf '%s\n' 'No secret values were printed.'
