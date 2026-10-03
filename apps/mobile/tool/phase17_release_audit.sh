#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "Phase 17 release audit failed: $*" >&2
  exit 1
}

git ls-files --error-unmatch pubspec.lock >/dev/null 2>&1 ||
  fail "pubspec.lock must be committed"

grep -q "branches:" ../../.github/workflows/mobile-ci.yml || fail "mobile CI branch gate missing"
grep -q -- "- main" ../../.github/workflows/mobile-ci.yml || fail "mobile CI must run for pushes to main"

if grep -q 'signingConfigs.getByName("debug")' android/app/build.gradle.kts; then
  fail "Android release must not use debug signing"
fi
for token in   SAVESTREAM_ANDROID_KEYSTORE_PATH   SAVESTREAM_ANDROID_KEYSTORE_PASSWORD   SAVESTREAM_ANDROID_KEY_ALIAS   SAVESTREAM_ANDROID_KEY_PASSWORD; do
  grep -q "$token" android/app/build.gradle.kts || fail "missing Android signing input $token"
done

grep -q 'SAVESTREAM_IOS_DEVELOPMENT_TEAM' ios/Flutter/Release.xcconfig ||
  fail "iOS release Team ID must be configurable"

grep -q "https://api.savestream.online" lib/core/config/app_config.dart ||
  fail "production API default is missing"
grep -q "MOBILE_EXTERNAL_CHECKOUT_ENABLED" lib/core/config/app_config.dart ||
  fail "native external checkout gate is missing"
grep -q "environment != AppEnvironment.production" lib/core/config/app_config.dart ||
  fail "production external checkout must default off"

grep -q "NotificationSettingsScreen" lib/app/router/app_router.dart ||
  fail "Notifications must use the real settings screen"
grep -q "/v1/me/notification-preferences"   lib/features/settings/data/repositories/api_notification_preferences_repository.dart ||
  fail "Notification preferences API integration is missing"

grep -q "https://savestream.online/privacy" lib/core/config/app_config.dart ||
  fail "published privacy URL is missing"
grep -q "https://savestream.online/terms" lib/core/config/app_config.dart ||
  fail "published terms URL is missing"

grep -q "flutter_launcher_icons:" pubspec.yaml ||
  fail "launcher icon generator is missing"
grep -q "flutter_native_splash:" pubspec.yaml ||
  fail "native splash generator is missing"

grep -q "billingPurchasesUnavailableTitle" lib/l10n/app_en.arb ||
  fail "billing-disabled UX copy is missing"

echo "Phase 17 mobile release audit passed."
