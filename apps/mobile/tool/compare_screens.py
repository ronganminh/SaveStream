"""Side-by-side sheets: emulator screenshot | artboard, one PNG per screen.

Usage: compare_screens.py <emulator_dir> <artboard_dir> [<artboard_dir> ...] <out_dir>

Each screenshot is matched with `<name>.artboard.png` from the first artboard
directory that has it (one directory per screen group, e.g. auth-home,
channels, credits and notifications).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw


def main(emulator_dir: str, *rest: str) -> int:
    if len(rest) < 2:
        print(__doc__)
        return 2
    *artboard_dirs, out_dir = rest
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    count = 0
    for shot in sorted(Path(emulator_dir).glob("*.png")):
        artboard = next(
            (
                Path(folder) / f"{shot.stem}.artboard.png"
                for folder in artboard_dirs
                if (Path(folder) / f"{shot.stem}.artboard.png").exists()
            ),
            None,
        )
        if artboard is None:
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
    sys.exit(main(*sys.argv[1:]))
