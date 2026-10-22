"""Side-by-side sheets: emulator screenshot | artboard, one PNG per screen.

Usage: compare_screens.py <emulator_dir> <artboard_dir> <out_dir>
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw


def main(emulator_dir: str, artboard_dir: str, out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    count = 0
    for shot in sorted(Path(emulator_dir).glob("*.png")):
        artboard = Path(artboard_dir) / f"{shot.stem}.artboard.png"
        if not artboard.exists():
            continue
        left = Image.open(shot).convert("RGB")
        right = Image.open(artboard).convert("RGB").resize(left.size)
        sheet = Image.new("RGB", (left.width * 2 + 24, left.height + 48), "white")
        sheet.paste(left, (0, 48))
        sheet.paste(right, (left.width + 24, 48))
        draw = ImageDraw.Draw(sheet)
        draw.text((8, 16), f"{shot.stem} - Android emulator", fill="black")
        draw.text((left.width + 32, 16), f"{shot.stem} - artboard", fill="black")
        sheet.save(out / f"{shot.stem}.png")
        count += 1
    print(f"{count} comparison sheets in {out}")
    return 0 if count else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
