#!/usr/bin/env python3
"""Idempotently configure iOS Google Sign-In from the local Firebase plist.

Run on the release/build Mac after downloading an updated GoogleService-Info.plist
from Firebase Console. Never commit that project configuration if it is ignored.
"""

from __future__ import annotations

import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIREBASE = ROOT / "ios/Runner/GoogleService-Info.plist"
INFO = ROOT / "ios/Runner/Info.plist"


def main() -> None:
    if not FIREBASE.is_file():
        raise SystemExit("Missing ios/Runner/GoogleService-Info.plist; download from Firebase.")

    with FIREBASE.open("rb") as stream:
        configuration = plistlib.load(stream)

    client_id = configuration.get("CLIENT_ID")
    reversed_id = configuration.get("REVERSED_CLIENT_ID")
    if not isinstance(client_id, str) or not client_id:
        raise SystemExit("Firebase iOS plist has no CLIENT_ID; enable Google sign-in first.")
    if not isinstance(reversed_id, str) or not reversed_id:
        raise SystemExit("Firebase iOS plist has no REVERSED_CLIENT_ID.")

    with INFO.open("rb") as stream:
        info = plistlib.load(stream)

    info["GIDClientID"] = client_id
    url_types = info.setdefault("CFBundleURLTypes", [])
    if not any(
        reversed_id in entry.get("CFBundleURLSchemes", [])
        for entry in url_types
        if isinstance(entry, dict)
    ):
        url_types.append({
            "CFBundleTypeRole": "Editor",
            "CFBundleURLSchemes": [reversed_id],
        })
    with INFO.open("wb") as stream:
        plistlib.dump(info, stream, sort_keys=False)
    print("iOS Google Sign-In app client and callback scheme configured.")


if __name__ == "__main__":
    main()
