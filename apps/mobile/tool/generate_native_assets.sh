#!/usr/bin/env bash
# Generates the launcher icons and native splash from the official brand SVG.
# They are build outputs and are not committed, so run this once after cloning
# (and whenever assets/branding/savestream_mark.svg changes) before a native build.
set -euo pipefail

cd "$(dirname "$0")/.."

python3 -m venv .brand-venv
.brand-venv/bin/python -m pip install --quiet --disable-pip-version-check cairosvg==2.7.1
.brand-venv/bin/python tool/generate_brand_assets.py

dart run flutter_launcher_icons
dart run flutter_native_splash:create
