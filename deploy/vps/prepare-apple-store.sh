#!/bin/sh
# Safely stage the App Store Server API credentials and Apple public trust roots.
# This does NOT deploy or change the running payment provider.
# Usage: prepare-apple-store.sh /secure/SubscriptionKey_XXXXXXXXXX.p8 KEYID ISSUER_UUID APP_APPLE_ID [sandbox|production]
set -eu
umask 077

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo 'Usage: prepare-apple-store.sh /secure/SubscriptionKey_KEYID.p8 KEYID ISSUER_UUID APP_APPLE_ID [sandbox|production]' >&2
  exit 2
fi

PRIVATE_KEY_PATH=$1
KEY_ID=$2
ISSUER_ID=$3
APP_APPLE_ID=$4
ENVIRONMENT=${5:-sandbox}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE=$SCRIPT_DIR/production.env

[ -r "$PRIVATE_KEY_PATH" ] || { echo 'In-App Purchase .p8 key file is not readable.' >&2; exit 2; }
[ -f "$ENV_FILE" ] || { echo 'production.env does not exist; initialize production first.' >&2; exit 2; }
case "$KEY_ID" in
  *[!A-Za-z0-9]*|'') echo 'Apple IAP Key ID must contain only letters and digits.' >&2; exit 2 ;;
esac
[ "${#KEY_ID}" -eq 10 ] || { echo 'Apple IAP Key ID must have 10 characters.' >&2; exit 2; }
case "$APP_APPLE_ID" in
  *[!0-9]*|''|0) echo 'Numeric App Store Connect app Apple ID is required.' >&2; exit 2 ;;
esac
case "$ISSUER_ID" in
  ????????-????-????-????-????????????) ;;
  *) echo 'Apple IAP Issuer ID must be a UUID.' >&2; exit 2 ;;
esac
case "$ENVIRONMENT" in sandbox|production) ;; *) echo 'Environment must be sandbox or production.' >&2; exit 2 ;; esac

# The IAP key is NOT the Apple Distribution signing certificate or the
# App Store Connect API Team key. Require a valid PEM private key.
openssl pkey -in "$PRIVATE_KEY_PATH" -noout >/dev/null 2>&1 || {
  echo 'The supplied file is not a readable PEM private key.' >&2
  exit 2
}

SECRETS_DIR=$(awk -F= '$1 == "SAVESTREAM_SECRETS_DIR" { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE")
[ -n "$SECRETS_DIR" ] || { echo 'SAVESTREAM_SECRETS_DIR missing in production.env.' >&2; exit 2; }
[ -d "$SECRETS_DIR" ] || { echo 'Production secrets directory is missing.' >&2; exit 2; }
[ -w "$SECRETS_DIR" ] || { echo 'Production secrets directory is not writable.' >&2; exit 2; }

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/savestream-apple-iap.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

# These exact certificates are linked under Apple Root Certificates on
# https://www.apple.com/certificateauthority/ (NOT public Internet CAs).
for entry in \
  'AppleIncRootCertificate https://www.apple.com/appleca/AppleIncRootCertificate.cer' \
  'AppleRootCA-G2 https://www.apple.com/certificateauthority/AppleRootCA-G2.cer' \
  'AppleRootCA-G3 https://www.apple.com/certificateauthority/AppleRootCA-G3.cer'; do
  name=${entry%% *}
  url=${entry#* }
  curl --fail --silent --show-error --location --max-time 25 "$url" -o "$WORK_DIR/$name.cer"
  openssl x509 -inform DER -in "$WORK_DIR/$name.cer" -noout >/dev/null 2>&1 || {
    echo 'Apple trust root download is not a DER X.509 certificate.' >&2
    exit 2
  }
done

python3 - "$WORK_DIR" <<'PY'
from pathlib import Path
import base64
import json
import sys

work = Path(sys.argv[1])
names = ('AppleIncRootCertificate', 'AppleRootCA-G2', 'AppleRootCA-G3')
roots = [base64.b64encode((work / f'{name}.cer').read_bytes()).decode('ascii') for name in names]
(work / 'roots.json').write_text(json.dumps(roots), encoding='utf-8')
print('Validated 3 Apple public root certificates.')
PY

# Never print private key bytes or include them in production.env / Git.
install -m 600 "$PRIVATE_KEY_PATH" "$SECRETS_DIR/app_store_private_key"
install -m 600 "$WORK_DIR/roots.json" "$SECRETS_DIR/app_store_root_certificates_json"

python3 - "$ENV_FILE" "$KEY_ID" "$ISSUER_ID" "$APP_APPLE_ID" "$ENVIRONMENT" <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import os
import shutil
import sys
import tempfile

env = Path(sys.argv[1])
settings = {
    'SAVESTREAM_APP_STORE_KEY_ID': sys.argv[2],
    'SAVESTREAM_APP_STORE_ISSUER_ID': sys.argv[3],
    'SAVESTREAM_APP_STORE_APP_APPLE_ID': sys.argv[4],
    'SAVESTREAM_APP_STORE_ENVIRONMENT': sys.argv[5],
}
lines = env.read_text().splitlines()
seen = set()
updated = []
for line in lines:
    key = line.split('=', 1)[0]
    if key in settings:
        if key not in seen:
            updated.append(f'{key}={settings[key]}')
        seen.add(key)
    else:
        updated.append(line)
for key, value in settings.items():
    if key not in seen:
        updated.append(f'{key}={value}')
backup = env.with_name(env.name + '.bak-before-apple-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
shutil.copy2(env, backup)
fd, tmp = tempfile.mkstemp(dir=env.parent, prefix='.apple-iap-env-')
try:
    os.chmod(tmp, 0o600)
    with os.fdopen(fd, 'w') as fp:
        fp.write('\n'.join(updated) + '\n')
    os.replace(tmp, env)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
print('Saved non-secret Apple identifiers, with production.env backup.')
PY

printf '%s\n' 'Apple IAP credentials staged (not activated).'
printf '%s\n' 'Use docker-compose.production.apple-store.yml ONLY after product availability is confirmed.'
printf '%s\n' 'No Apple private key or secret contents were printed.'
