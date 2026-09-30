from __future__ import annotations

import argparse
import sys

import httpx


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    with httpx.Client(timeout=args.timeout, follow_redirects=False) as client:
        for path in ("/health/live", "/health/ready"):
            response = client.get(base + path)
            if response.status_code != 200:
                print(f"FAIL {path}: {response.status_code}", file=sys.stderr)
                return 1

        response = client.get(base + "/health/live")
        required_headers = {
            "x-content-type-options": "nosniff",
            "x-frame-options": "DENY",
            "referrer-policy": "no-referrer",
        }
        for header, expected in required_headers.items():
            if response.headers.get(header) != expected:
                print(f"FAIL missing security header {header}", file=sys.stderr)
                return 1
    print("canary checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
