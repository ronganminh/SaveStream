from __future__ import annotations

from pathlib import Path

import cairosvg


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "savestream_mark.svg"
OUTPUT = ROOT / "build" / "branding" / "savestream_app_icon.png"


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Brand source is missing: {SOURCE}")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        url=str(SOURCE),
        write_to=str(OUTPUT),
        output_width=1024,
        output_height=1024,
    )

    signature = OUTPUT.read_bytes()[:8]
    if signature != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("Generated app icon is not a valid PNG.")

    print(f"Generated {OUTPUT.relative_to(ROOT)} from {SOURCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
