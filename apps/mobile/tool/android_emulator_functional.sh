#!/usr/bin/env bash
# Real Android emulator launch + on-device Flutter integration journeys.
# Uses only CI Firebase placeholders and mocked ads/billing for UI journeys.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/ci
android_device="${ANDROID_EMULATOR_ID:-$(adb devices | awk '/^emulator-[0-9]+[[:space:]]+device/{print $1; exit}')}"
if [[ -z "$android_device" ]]; then
  echo 'No booted Android emulator was found.' >&2
  exit 1
fi

media_server_pid=''
on_exit() {
  status=$?
  if [[ -n "$media_server_pid" ]]; then
    kill "$media_server_pid" 2>/dev/null || true
  fi
  if [[ "$status" -ne 0 ]]; then
    adb -s "$android_device" logcat -d -t 600 > build/ci/android-logcat.txt 2>&1 || true
    adb -s "$android_device" shell screencap -p /sdcard/savestream-ci-failure.png || true
    adb -s "$android_device" pull /sdcard/savestream-ci-failure.png build/ci/android-failure.png >/dev/null 2>&1 || true
  fi
}
trap on_exit EXIT

# Validate the actual production bootstrap/native Firebase plugins first.
bash tool/android_emulator_smoke.sh

# Host a real MP4 and an actual FLV byte stream, safely, on the CI runner.
# adb reverse makes loopback reach the host from Android's native service.
ffmpeg -hide_banner -loglevel error -y \
  -i ../../apps/web/public/samples/video-01.mp4 \
  -c copy -f flv build/ci/ci-stream.flv
python3 tool/ci_media_server.py --port 18095 \
  --flv build/ci/ci-stream.flv > build/ci/media-server.log 2>&1 &
media_server_pid=$!
for attempt in $(seq 1 20); do
  if curl --fail --silent http://127.0.0.1:18095/health >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18095/health >/dev/null
adb -s "$android_device" reverse tcp:18095 tcp:18095

# Android's actual Flutter engine, plugin channels, recorder service and player.
set -o pipefail
flutter test integration_test/native_journeys_test.dart \
  -d "$android_device" --reporter expanded 2>&1 | tee build/ci/android-functional.txt
flutter test integration_test/native_media_test.dart \
  -d "$android_device" --reporter expanded \
  --dart-define=CI_MEDIA_HOST=127.0.0.1 \
  --dart-define=CI_MEDIA_PORT=18095 2>&1 | tee build/ci/android-media.txt

# Ad SDK network availability is not deterministic. This uses only Google's
# official TEST units, never opens a fullscreen ad or grants fake credits.
if flutter test integration_test/native_admob_sdk_test.dart -d "$android_device" \
  --reporter expanded > build/ci/android-admob-network.txt 2>&1; then
  echo 'Google AdMob test-unit SDK load: PASS (Android)'
else
  echo '::warning::Google TEST inventory unavailable on Android runner; inspect android-admob-network.txt'
fi
