#!/usr/bin/env bash
# Real Android emulator launch + on-device Flutter integration journeys.
# Uses only CI Firebase placeholders and mocked billing for UI journeys.
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

# Host a real MP4, safely, on the CI runner.
# adb reverse makes loopback reach the host from the Android emulator.
python3 tool/ci_media_server.py --port 18095 > build/ci/media-server.log 2>&1 &
media_server_pid=$!
for attempt in $(seq 1 20); do
  if curl --fail --silent http://127.0.0.1:18095/health >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18095/health >/dev/null
adb -s "$android_device" reverse tcp:18095 tcp:18095

# The emulator sometimes gets stuck after installing the APK without ever
# connecting the Dart VM Service. Fail in bounded time, restart the app and
# retry once. Only a timeout (exit 124) is retried; assertion failures and
# player regressions still fail the job. Never silently skip failures.
set -o pipefail
run_android_suite() {
  local label="$1"
  local deadline="$2"
  shift 2
  local attempt result logfile since
  for attempt in 1 2; do
    logfile="build/ci/android-${label}.txt"
    echo "Android ${label} device test attempt ${attempt}/2 (limit ${deadline}s)"
    # Device clock, for reading only this attempt's logcat afterwards.
    since="$(adb -s "$android_device" shell date "'+%m-%d %H:%M:%S.000'" 2>/dev/null | tr -d '\r' || true)"
    if python3 tool/ci_deadline.py --seconds "$deadline" -- \
      flutter test "$@" -d "$android_device" --reporter expanded \
      2>&1 | tee "$logfile"; then
      echo "Android ${label} device tests PASS"
      return 0
    else
      result=${PIPESTATUS[0]}
      echo "::warning::Android ${label} attempt ${attempt} exited ${result}"
    fi
    # Retry once only for infrastructure: a startup hang (timeout, exit 124)
    # or the emulator dropping off adb mid-run. The drop shows either as
    # "device offline" from flutter, or only on the device: adbd logs
    # "host-N: offline", flutter loses the VM Service, every test "did not
    # complete" and it exits 79 (no test finished). Test assertion failures
    # are never retried.
    local offline=0
    if grep -q 'device offline' "$logfile"; then
      offline=1
    fi
    # Say why it failed: did adb drop the host, or did the app die?
    local adbd_log app_pid
    adbd_log="$(adb -s "$android_device" logcat -d ${since:+-T "$since"} -s adbd 2>/dev/null || true)"
    app_pid="$(adb -s "$android_device" shell pidof com.savestream.app 2>/dev/null | tr -d '\r' || true)"
    {
      echo "--- ${label} attempt ${attempt} diagnostics (exit ${result})"
      echo "app process: ${app_pid:-not running}"
      echo "adbd since ${since:-boot}:"
      printf '%s\n' "$adbd_log" | grep -E 'host-[0-9]+: (offline|connection terminated)|flushing socket' \
        || echo '(no adb transport drop logged)'
    } | tee -a "build/ci/android-${label}-diagnostics.txt"
    if printf '%s\n' "$adbd_log" | grep -qE 'host-[0-9]+: offline'; then
      offline=1
    fi
    if [[ "$attempt" -eq 2 || ( "$result" -ne 124 && "$offline" -eq 0 ) ]]; then
      return "$result"
    fi
    if [[ "$offline" -eq 1 ]]; then
      echo '::warning::The emulator went offline during the run; reconnecting before the retry.'
      adb reconnect offline || true
      timeout 180 adb -s "$android_device" wait-for-device || return "$result"
      timeout 180 bash -c "until [[ \"\$(adb -s $android_device shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')\" == 1 ]]; do sleep 2; done" \
        || return "$result"
    fi
    # Start the retry from a clean device state: the killed flutter tool can
    # leave the app process and adb forwards behind, and the next run then
    # loses its VM Service (VmServiceDisappearedException).
    echo '::warning::Reinstalling the app on the emulator before the retry.'
    adb -s "$android_device" shell am force-stop com.savestream.app || true
    adb -s "$android_device" uninstall com.savestream.app || true
    adb -s "$android_device" forward --remove-all || true
    adb -s "$android_device" reverse --remove-all || true
    adb -s "$android_device" reverse tcp:18095 tcp:18095 || true
    sleep 5
  done
}

# Android's actual Flutter engine, plugin channels and player.
run_android_suite functional 600 integration_test/native_journeys_test.dart
run_android_suite media 600 integration_test/native_media_test.dart \
  --dart-define=CI_MEDIA_HOST=127.0.0.1 \
  --dart-define=CI_MEDIA_PORT=18095

# v2 screens (Auth + Home, Channels, Recordings + Player, Notifications,
# Credits, Account, System) rendered on the emulator, pulled next to the artboards for review
# (artifact android-emulator-screens).
run_android_suite screens 600 integration_test/auth_home_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens.txt build/screens
run_android_suite screens-channels 600 integration_test/channels_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens-channels.txt build/screens
run_android_suite screens-recordings 600 integration_test/recordings_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens-recordings.txt build/screens
run_android_suite screens-notifications 600 integration_test/notifications_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens-notifications.txt build/screens
run_android_suite screens-credits 600 integration_test/credits_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens-credits.txt build/screens
run_android_suite screens-account 600 integration_test/account_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens-account.txt build/screens
run_android_suite screens-system 600 integration_test/system_screenshots_test.dart \
  --dart-define=SAVESTREAM_SCREENSHOT_DIR=device
python3 tool/decode_screens.py build/ci/android-screens-system.txt build/screens
python3 -m pip install --quiet --user pillow
python3 tool/compare_screens.py build/screens \
  ../../docs/mobile-v2/screens/auth-home \
  ../../docs/mobile-v2/screens/channels \
  ../../docs/mobile-v2/screens/recordings \
  ../../docs/mobile-v2/screens/notifications \
  ../../docs/mobile-v2/screens/credits \
  ../../docs/mobile-v2/screens/account \
  ../../docs/mobile-v2/screens/system \
  build/screens/compare
ls -l build/screens build/screens/compare
