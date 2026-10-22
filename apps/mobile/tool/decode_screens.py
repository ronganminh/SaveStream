"""Rebuild PNGs printed by the device screenshot test (`SS-SCREEN name chunk`).

Usage: decode_screens.py <test_log> <out_dir>
"""

from __future__ import annotations

import base64
import re
import sys
from collections import OrderedDict
from pathlib import Path

LINE = re.compile(r"SS-SCREEN (\S+) ([A-Za-z0-9+/=]+)\s*$")


def main(log: str, out_dir: str) -> int:
    chunks: OrderedDict[str, list[str]] = OrderedDict()
    for raw in Path(log).read_text(encoding="utf-8", errors="replace").splitlines():
        match = LINE.search(raw)
        if match:
            chunks.setdefault(match.group(1), []).append(match.group(2))
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, parts in chunks.items():
        (out / f"{name}.png").write_bytes(base64.b64decode("".join(parts)))
    print(f"{len(chunks)} screenshots decoded into {out}")
    return 0 if chunks else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
