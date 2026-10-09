#!/usr/bin/env bash
# Boot an iPhone Simulator and exercise the real app router, widgets and plugins.
# Product, AdMob and auth provider calls are deterministic fakes; no paid events.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/ci
# Prefer the user-supplied UDID, otherwise select an available iPhone simulator
# from the runner's installed Xcode, without assuming a particular iOS version.
ios_device="${IOS_SIMULATOR_ID:-}"
if [[ -z "$ios_device" ]]; then
  ios_device="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
r=json.load(sys.stdin)
options=[d for devices in r["devices"].values() for d in devices if d.get("isAvailable",True) and d["name"].startswith("iPhone")]
options.sort(key=lambda d: (d["state"]!="Booted", "Pro" not in d["name"], d["name"]))
if not options:sys.exit("No available iPhone Simulator is installed")
print(options[0]["udid"])
')"
fi

media_server_pid=''
on_exit() {
  status=$?
  if [[ -n "$media_server_pid" ]]; then
    kill "$media_server_pid" 2>/dev/null || true
  fi
  if [[ "$status" -ne 0 ]]; then
    xcrun simctl io "$ios_device" screenshot build/ci/ios-failure.png 2>/dev/null || true
    xcrun simctl spawn "$ios_device" log show --last 3m --style compact \
      --predicate 'process == "Runner"' > build/ci/ios-runner.log 2>&1 || true
  fi
}
trap on_exit EXIT

if ! xcrun simctl list devices booted | grep -Fq "$ios_device"; then
  xcrun simctl boot "$ios_device"
fi
xcrun simctl bootstatus "$ios_device" -b
flutter devices

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

# Flutter integration_test runs on-device via Xcode and the iOS Flutter engine.
set -o pipefail
flutter test integration_test/native_journeys_test.dart \
  -d "$ios_device" --reporter expanded 2>&1 | tee build/ci/ios-functional.txt
flutter test integration_test/native_media_test.dart \
  -d "$ios_device" --reporter expanded \
  --dart-define=CI_MEDIA_HOST=127.0.0.1 \
  --dart-define=CI_MEDIA_PORT=18095 2>&1 | tee build/ci/ios-media.txt

# Non-gating network-dependent AdMob test inventory and SSV parameter setup.
if flutter test integration_test/native_admob_sdk_test.dart -d "$ios_device" \
  --reporter expanded > build/ci/ios-admob-network.txt 2>&1; then
  echo 'Google AdMob test-unit SDK load: PASS (iOS)'
else
  echo '::warning::Google TEST inventory unavailable on iOS runner; inspect ios-admob-network.txt'
fi
