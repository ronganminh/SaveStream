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
          "current_key": "AIzaSyDUMMY_CI_KEY_NOT_FOR_PRODUCTION"
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
  <string>AIzaSyDUMMY_CI_KEY_NOT_FOR_PRODUCTION</string>
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
