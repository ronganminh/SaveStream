#!/usr/bin/env bash
# Boot an iPhone Simulator and exercise the real app router, widgets and plugins.
# Product, AdMob and auth provider calls are deterministic fakes; no paid events.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/ci
# Match the iOS Simulator runtime to the selected Xcode 26.3 SDK. Previously,
# the runner silently selected a booted iOS 18.5 simulator while compiling with
# Xcode 26.3, followed by a Flutter VM-service/debug-log connection hang.
# Never mask missing iOS 26.2 with an unrelated older runtime.
ios_device="${IOS_SIMULATOR_ID:-}"
if [[ -z "$ios_device" ]]; then
  ios_device="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
r=json.load(sys.stdin)
runtime="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
options=[d for d in r["devices"].get(runtime,[]) if d.get("isAvailable",True) and d["name"].startswith("iPhone")]
if not options:
  sys.exit("iOS 26.2 iPhone Simulator is missing; check the Xcode 26.3 runner image")
options.sort(key=lambda d: (d["name"] != "iPhone 17 Pro", d["state"]!="Booted", d["name"]))
print(options[0]["udid"])
')"
fi
printf 'Selected iOS 26.2 test device: %s\n' "$ios_device"
xcrun simctl list devices | grep -F "$ios_device" || true

media_server_pid=''
on_exit() {
  status=$?
  if [[ -n "$media_server_pid" ]]; then
    kill "$media_server_pid" 2>/dev/null || true
  fi
  if [[ "$status" -ne 0 ]]; then
    xcrun simctl io "$ios_device" screenshot build/ci/ios-failure.png 2>/dev/null || true
    xcrun simctl spawn "$ios_device" log show --last 10m --style compact \
      --predicate 'process == "Runner" OR process == "runningboardd" OR eventMessage CONTAINS "com.savestream.app"' \
      > build/ci/ios-runner.log 2>&1 || true
    find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 \
      -iname '*Runner*' -type f -mmin -50 \
      -exec cp {} build/ci/ \; 2>/dev/null || true
  fi
}
trap on_exit EXIT

if ! xcrun simctl list devices booted | grep -Fq "$ios_device"; then
  xcrun simctl boot "$ios_device"
fi
python3 tool/ci_deadline.py --seconds 180 -- \
  xcrun simctl bootstatus "$ios_device" -b
python3 tool/ci_deadline.py --seconds 75 -- flutter devices

# Serve an actual H.264/AAC MP4 for native AVPlayer decoding; never request
# ads, App Store purchases or livestreams from outside the CI runner.
python3 tool/ci_media_server.py --port 18095 > build/ci/media-server.log 2>&1 &
media_server_pid=$!
for attempt in $(seq 1 20); do
  if curl --fail --silent http://127.0.0.1:18095/health >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18095/health >/dev/null

# An iOS Simulator sometimes gets stuck after "Xcode build done" without ever
# connecting Dart VM Service. Fail in bounded time, reboot and retry once on a
# fresh simulator process. All tests remain gating; never silently skip failures.
run_ios_suite() {
  local label="$1"
  local deadline="$2"
  shift 2
  local attempt result logfile
  for attempt in 1 2; do
    logfile="build/ci/ios-${label}-attempt-${attempt}.txt"
    echo "iOS ${label} device test attempt ${attempt}/2 (limit ${deadline}s)"
    if python3 tool/ci_deadline.py --seconds "$deadline" -- \
      flutter test "$@" -d "$ios_device" --reporter expanded \
      2>&1 | tee "$logfile"; then
      echo "iOS ${label} device tests PASS"
      return 0
    else
      result=${PIPESTATUS[0]}
      echo "::warning::iOS ${label} attempt ${attempt} exited ${result}"
    fi
    # Retry only missing VM-service startup / process hang, not assertion
    # failures or a media/player regression.
    if [[ "$result" -ne 124 || "$attempt" -eq 2 ]]; then
      return "$result"
    fi
    echo '::warning::Resetting stuck iPhone Simulator after test startup timeout.'
    xcrun simctl terminate "$ios_device" com.savestream.app 2>/dev/null || true
    xcrun simctl shutdown "$ios_device" || true
    xcrun simctl boot "$ios_device"
    python3 tool/ci_deadline.py --seconds 180 -- \
      xcrun simctl bootstatus "$ios_device" -b
  done
}

# Keep every run bounded so the CI reaches log/artifact upload on failures.
run_ios_suite functional 420 integration_test/native_journeys_test.dart
run_ios_suite media 420 integration_test/native_media_test.dart \
  --dart-define=CI_MEDIA_HOST=127.0.0.1 \
  --dart-define=CI_MEDIA_PORT=18095

# Native test-unit SDK loading is network dependent; never creates real
# advertising impressions, and failure here must not block app functionality.
if python3 tool/ci_deadline.py --seconds 360 -- \
  flutter test integration_test/native_admob_sdk_test.dart \
  -d "$ios_device" --reporter expanded \
  > build/ci/ios-admob-network.txt 2>&1; then
  echo 'Google AdMob test-unit SDK load: PASS (iOS)'
else
  echo '::warning::Google TEST inventory unavailable on iOS runner; inspect ios-admob-network.txt'
fi
