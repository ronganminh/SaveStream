#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build apk --debug \
  --dart-define=APP_ENV=production \
  --dart-define=MOBILE_EXTERNAL_CHECKOUT_ENABLED=false

apk="build/app/outputs/flutter-apk/app-debug.apk"
test -f "$apk"

adb install -r "$apk" >/dev/null
adb shell am force-stop com.savestream.app
adb logcat -c
adb shell am start -W -n com.savestream.app/.MainActivity
sleep 8

pid="$(adb shell pidof com.savestream.app | tr -d '\r')"
if [[ -z "$pid" ]]; then
  echo "SaveStream process is not running after emulator launch." >&2
  adb logcat -d -t 300 >&2
  exit 1
fi

if adb logcat -d -t 300 | grep -E "FATAL EXCEPTION|Process: com\.savestream\.app.*has died" >/dev/null; then
  echo "SaveStream crashed during emulator smoke test." >&2
  adb logcat -d -t 300 >&2
  exit 1
fi

echo "Android emulator smoke passed (pid $pid)."
