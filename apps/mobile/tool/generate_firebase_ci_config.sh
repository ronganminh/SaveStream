#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p android/app ios/Runner

cat > android/app/google-services.json <<'JSON'
{
  "project_info": {
    "project_number": "1234567890",
    "project_id": "savestream-ci",
    "storage_bucket": "savestream-ci.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:1234567890:android:0000000000000000",
        "android_client_info": {
          "package_name": "com.savestream.app"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSy000000000000000000000000000000000"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
JSON

cat > ios/Runner/GoogleService-Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>
  <string>AIzaSy000000000000000000000000000000000</string>
  <key>GCM_SENDER_ID</key>
  <string>1234567890</string>
  <key>PLIST_VERSION</key>
  <string>1</string>
  <key>BUNDLE_ID</key>
  <string>com.savestream.app</string>
  <key>PROJECT_ID</key>
  <string>savestream-ci</string>
  <key>GOOGLE_APP_ID</key>
  <string>1:1234567890:ios:0000000000000000</string>
</dict>
</plist>
PLIST

# Firebase Installations validates API key *syntax* during iOS plugin
# registration, before the Dart integration_test runner can start. An invalid
# placeholder crashes the app with FIRInstallations validateAPIKey SIGABRT.
# The all-zero suffix is intentionally NOT a real Google/Firebase credential.
python3 - <<'PY_VALIDATE_CI_FIREBASE'
import json
import plistlib
import re
from pathlib import Path
android = json.loads(Path('android/app/google-services.json').read_text())
ios = plistlib.loads(Path('ios/Runner/GoogleService-Info.plist').read_bytes())
android_key = android['client'][0]['api_key'][0]['current_key']
ios_key = ios['API_KEY']
assert android_key == ios_key, 'Android/iOS CI Firebase API keys must match'
assert re.fullmatch(r'AIza[A-Za-z0-9_-]{35}', ios_key), (
    'Firebase Installations iOS requires a syntactically valid 39-character API key'
)
assert ios_key[6:] == '0' * 33, 'CI must not use a real Firebase API credential'
assert ios['BUNDLE_ID'] == 'com.savestream.app'
print('CI Firebase placeholder shape valid; no production credentials used.')
PY_VALIDATE_CI_FIREBASE
