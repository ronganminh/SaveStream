#!/usr/bin/env python3
"""Prepare small web-safe sample media from a Drive download.

The script ranks source videos/images using simple visual-quality heuristics,
creates landscape thumbnails and short preview clips, and writes a TypeScript
manifest consumed by the frontend.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import cv2
import numpy as np
from PIL import Image, ImageFilter

VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".webm", ".m4v", ".avi"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


@dataclass
class Candidate:
    path: Path
    kind: str
    score: float
    width: int
    height: int
    duration: float = 0.0
    best_time: float = 0.0
    best_frame: Path | None = None


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def ffprobe(path: Path) -> dict:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height:format=duration",
            "-of",
            "json",
            str(path),
        ]
    )
    return json.loads(result.stdout)


def visual_score(image: np.ndarray) -> float:
    if image is None or image.size == 0:
        return -1_000.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    brightness = float(gray.mean())
    contrast = float(gray.std())
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    clipped = float(((gray < 10) | (gray > 245)).mean())
    exposure = max(0.0, 1.0 - abs(brightness - 128.0) / 128.0)

    # Favour readable, sharp frames while penalising mostly black/white frames.
    return (
        math.log1p(max(sharpness, 0.0)) * 9.0
        + contrast * 0.35
        + exposure * 26.0
        - clipped * 80.0
    )


def resolution_bonus(width: int, height: int) -> float:
    pixels = max(width * height, 1)
    return min(math.log2(pixels / (640 * 360) + 1.0) * 7.0, 18.0)


def extract_frame(video: Path, timestamp: float, output: Path) -> bool:
    output.parent.mkdir(parents=True, exist_ok=True)
    result = run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            f"{timestamp:.3f}",
            "-i",
            str(video),
            "-frames:v",
            "1",
            "-vf",
            "scale=1280:1280:force_original_aspect_ratio=decrease",
            "-q:v",
            "2",
            "-y",
            str(output),
        ],
        check=False,
    )
    return result.returncode == 0 and output.exists() and output.stat().st_size > 0


def analyse_video(path: Path, scratch: Path) -> Candidate | None:
    try:
        metadata = ffprobe(path)
        streams = metadata.get("streams", [])
        if not streams:
            return None
        stream = streams[0]
        width = int(stream.get("width") or 0)
        height = int(stream.get("height") or 0)
        duration = float(metadata.get("format", {}).get("duration") or 0.0)
        if width <= 0 or height <= 0 or duration <= 0.5:
            return None

        ratios = (0.12, 0.3, 0.5, 0.7, 0.88)
        best_score = -1_000.0
        best_time = 0.0
        best_frame: Path | None = None

        for index, ratio in enumerate(ratios):
            timestamp = min(max(duration * ratio, 0.0), max(duration - 0.2, 0.0))
            frame = scratch / f"{path.stem[:48]}-{index}.jpg"
            if not extract_frame(path, timestamp, frame):
                continue
            image = cv2.imread(str(frame))
            score = visual_score(image)
            if score > best_score:
                best_score = score
                best_time = timestamp
                best_frame = frame

        if best_frame is None:
            return None

        duration_bonus = min(math.log1p(duration) * 1.8, 13.0)
        total = best_score + resolution_bonus(width, height) + duration_bonus
        return Candidate(path, "video", total, width, height, duration, best_time, best_frame)
    except Exception as exc:  # noqa: BLE001
        print(f"Skipping video {path}: {exc}", file=sys.stderr)
        return None


def analyse_image(path: Path) -> Candidate | None:
    try:
        image = cv2.imread(str(path))
        if image is None:
            return None
        height, width = image.shape[:2]
        if width < 320 or height < 320:
            return None
        total = visual_score(image) + resolution_bonus(width, height)
        return Candidate(path, "image", total, width, height)
    except Exception as exc:  # noqa: BLE001
        print(f"Skipping image {path}: {exc}", file=sys.stderr)
        return None


def landscape_canvas(source: Image.Image, width: int = 1280, height: int = 720) -> Image.Image:
    source = source.convert("RGB")
    background = source.copy()
    background.thumbnail((width * 2, height * 2))

    bg_ratio = max(width / source.width, height / source.height)
    bg_size = (max(1, round(source.width * bg_ratio)), max(1, round(source.height * bg_ratio)))
    background = source.resize(bg_size, Image.Resampling.LANCZOS)
    left = max((background.width - width) // 2, 0)
    top = max((background.height - height) // 2, 0)
    background = background.crop((left, top, left + width, top + height)).filter(ImageFilter.GaussianBlur(24))

    fg_ratio = min((width * 0.88) / source.width, (height * 0.92) / source.height)
    fg_size = (max(1, round(source.width * fg_ratio)), max(1, round(source.height * fg_ratio)))
    foreground = source.resize(fg_size, Image.Resampling.LANCZOS)

    canvas = background.copy()
    x = (width - foreground.width) // 2
    y = (height - foreground.height) // 2
    canvas.paste(foreground, (x, y))
    return canvas


def save_thumbnail(source: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        canvas = landscape_canvas(image)
        canvas.save(output, "WEBP", quality=84, method=6)


def create_clip(source: Path, start: float, output: Path, clip_seconds: float) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    filter_graph = (
        "[0:v]split=2[bgsrc][fgsrc];"
        "[bgsrc]scale=854:480:force_original_aspect_ratio=increase,crop=854:480,boxblur=22:10[bg];"
        "[fgsrc]scale=854:480:force_original_aspect_ratio=decrease[fg];"
        "[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p[outv]"
    )
    result = run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            f"{max(start, 0.0):.3f}",
            "-i",
            str(source),
            "-t",
            f"{clip_seconds:.3f}",
            "-filter_complex",
            filter_graph,
            "-map",
            "[outv]",
            "-map",
            "0:a?",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "30",
            "-c:a",
            "aac",
            "-b:a",
            "64k",
            "-movflags",
            "+faststart",
            "-y",
            str(output),
        ],
        check=False,
    )
    if result.returncode != 0 or not output.exists():
        raise RuntimeError(result.stderr.strip() or f"Could not create clip for {source}")


def iter_files(root: Path, extensions: set[str]) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in extensions:
            yield path


def write_typescript(items: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    body = json.dumps(items, ensure_ascii=False, indent=2)
    output.write_text(
        "export type SampleMediaKind = \"video\" | \"image\";\n\n"
        "export interface SampleMediaItem {\n"
        "  id: string;\n"
        "  kind: SampleMediaKind;\n"
        "  title: string;\n"
        "  mediaUrl: string;\n"
        "  thumbnailUrl: string;\n"
        "  durationSeconds?: number;\n"
        "  width: number;\n"
        "  height: number;\n"
        "}\n\n"
        f"export const sampleMedia: SampleMediaItem[] = {body};\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--public-dir", type=Path, required=True)
    parser.add_argument("--data-file", type=Path, required=True)
    parser.add_argument("--max-videos", type=int, default=4)
    parser.add_argument("--max-images", type=int, default=6)
    parser.add_argument("--clip-seconds", type=float, default=180.0)
    args = parser.parse_args()

    if not args.input.exists():
        raise SystemExit(f"Input directory does not exist: {args.input}")

    scratch = Path(".sample-work")
    shutil.rmtree(scratch, ignore_errors=True)
    scratch.mkdir(parents=True)
    shutil.rmtree(args.public_dir, ignore_errors=True)
    args.public_dir.mkdir(parents=True)

    videos = [candidate for path in iter_files(args.input, VIDEO_EXTENSIONS) if (candidate := analyse_video(path, scratch))]
    images = [candidate for path in iter_files(args.input, IMAGE_EXTENSIONS) if (candidate := analyse_image(path))]
    videos.sort(key=lambda item: item.score, reverse=True)
    images.sort(key=lambda item: item.score, reverse=True)

    featured = [item for item in videos if "FEATURED_REPLACEMENT" in item.path.name.upper()]
    regular = [item for item in videos if item not in featured]
    selected_videos = (featured[:1] + regular)[: args.max_videos]
    selected_images = images[: args.max_images]
    items: list[dict] = []
    report: list[dict] = []

    for index, candidate in enumerate(selected_videos, start=1):
        stem = f"video-{index:02d}"
        thumb_name = f"{stem}.webp"
        clip_name = f"{stem}.mp4"
        assert candidate.best_frame is not None
        save_thumbnail(candidate.best_frame, args.public_dir / thumb_name)
        clip_seconds = min(args.clip_seconds, candidate.duration)
        clip_start = max(0.0, min(candidate.best_time - clip_seconds / 2.0, max(candidate.duration - clip_seconds, 0.0)))
        create_clip(candidate.path, clip_start, args.public_dir / clip_name, clip_seconds)
        items.append(
            {
                "id": stem,
                "kind": "video",
                "title": f"Recorded livestream sample {index}",
                "mediaUrl": f"/samples/{clip_name}",
                "thumbnailUrl": f"/samples/{thumb_name}",
                "durationSeconds": round(candidate.duration, 1),
                "width": candidate.width,
                "height": candidate.height,
            }
        )
        report.append(
            {
                "id": stem,
                "source": candidate.path.name,
                "score": round(candidate.score, 2),
                "bestTime": round(candidate.best_time, 2),
                "duration": round(candidate.duration, 2),
                "dimensions": [candidate.width, candidate.height],
            }
        )

    for index, candidate in enumerate(selected_images, start=1):
        stem = f"image-{index:02d}"
        image_name = f"{stem}.webp"
        save_thumbnail(candidate.path, args.public_dir / image_name)
        items.append(
            {
                "id": stem,
                "kind": "image",
                "title": f"Recording thumbnail sample {index}",
                "mediaUrl": f"/samples/{image_name}",
                "thumbnailUrl": f"/samples/{image_name}",
                "width": candidate.width,
                "height": candidate.height,
            }
        )
        report.append(
            {
                "id": stem,
                "source": candidate.path.name,
                "score": round(candidate.score, 2),
                "dimensions": [candidate.width, candidate.height],
            }
        )

    if not items:
        raise SystemExit("No usable image or video files were found in the Drive download.")

    write_typescript(items, args.data_file)
    (args.public_dir / "manifest.json").write_text(
        json.dumps({"items": items, "selectionReport": report}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (args.public_dir / "README.md").write_text(
        "# Generated sample media\n\n"
        "These files are automatically selected and optimized from the configured Google Drive folder.\n"
        "Only optimized three-minute web preview clips and thumbnails are committed; original recordings remain in Drive.\n",
        encoding="utf-8",
    )

    print(f"Selected {len(selected_videos)} videos and {len(selected_images)} images.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
