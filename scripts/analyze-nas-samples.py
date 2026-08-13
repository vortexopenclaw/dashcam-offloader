#!/usr/bin/env python3
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

MEDIA_EXTENSIONS = {".mp4", ".mov", ".avi"}


def raw_name(path: Path) -> str:
    stem = path.stem
    # Archive folder names may append human descriptions after the original dashcam token.
    # Keep only the camera-looking filename prefix for private-safe pattern work.
    return stem.split(" ", 1)[0]


def pattern_for(token: str) -> str:
    upper = token.upper()
    if re.match(r"^\d{14}_\d+[A-Z]*$", upper):
        return re.sub(r"^(\d{14})_(\d+)([A-Z]*)$", r"YYYYMMDDHHMMSS_SEQ\3", upper)
    if re.match(r"^\d{4}_\d{4}_\d{6}_\d+[A-Z]+$", upper):
        return re.sub(r"^(\d{4})_(\d{4})_(\d{6})_(\d+)([A-Z]+)$", r"YYYY_MMDD_HHMMSS_SEQ\5", upper)
    if re.match(r"^\d{4}_\d{4}_\d{6}_[A-Z]+$", upper):
        return re.sub(r"^(\d{4})_(\d{4})_(\d{6})_([A-Z]+)$", r"YYYY_MMDD_HHMMSS_\4", upper)
    if re.match(r"^\d{8}_\d{6}_\d+_[A-Z]_[A-Z]$", upper):
        return re.sub(r"^(\d{8})_(\d{6})_(\d+)_([A-Z])_([A-Z])$", r"YYYYMMDD_HHMMSS_SEQ_\4_\5", upper)
    if re.match(r"^\d{4}_\d{2}_\d{2}_\d{6}_[A-Z]_[A-Z]$", upper):
        return re.sub(r"^(\d{4})_(\d{2})_(\d{2})_(\d{6})_([A-Z])_([A-Z])$", r"YYYY_MM_DD_HHMMSS_\5_\6", upper)
    if re.match(r"^(NO|LA|PA|EV)\d{8}-\d{6}-\d+[A-Z]*$", upper):
        return re.sub(r"^(NO|LA|PA|EV)(\d{8})-(\d{6})-(\d+)([A-Z]*)$", r"\1YYYYMMDD-HHMMSS-SEQ\5", upper)
    if re.match(r"^(REC|MAN|PAK|MOT|EVT)_\d{8}_\d{6}_[A-Z]+$", upper):
        return re.sub(r"^(REC|MAN|PAK|MOT|EVT)_(\d{8})_(\d{6})_([A-Z]+)$", r"\1_YYYYMMDD_HHMMSS_\4", upper)
    if re.match(r"^(REC|MAN|PAK|MOT|EVT)_\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}_[A-Z]+$", upper):
        return re.sub(r"^(REC|MAN|PAK|MOT|EVT)_(\d{4})_(\d{2})_(\d{2})_(\d{2})_(\d{2})_(\d{2})_([A-Z]+)$", r"\1_YYYY_MM_DD_HH_MM_SS_\8", upper)
    if re.match(r"^\d{6}_\d{6}_\d{3}_[A-Z]+$", upper):
        return re.sub(r"^(\d{6})_(\d{6})_(\d{3})_([A-Z]+)$", r"YYMMDD_HHMMSS_SEQ_\4", upper)
    if re.match(r"^\d{8}_\d{6}_\d+[A-Z]+$", upper):
        return re.sub(r"^(\d{8})_(\d{6})_(\d+)([A-Z]+)$", r"YYYYMMDD_HHMMSS_SEQ\4", upper)
    if re.match(r"^\d{8}_\d{6}[A-Z]+$", upper):
        return re.sub(r"^(\d{8})_(\d{6})([A-Z]+)$", r"YYYYMMDD_HHMMSS\3", upper)
    token = re.sub(r"\d{8}", "YYYYMMDD", token)
    token = re.sub(r"\d{6}", "HHMMSS", token)
    token = re.sub(r"\d{4}", "YYYY", token)
    token = re.sub(r"\d{3,}", "NNN", token)
    token = re.sub(r"\d", "N", token)
    return token


def list_media(root: Path) -> list[Path]:
    if not root.exists():
        return []
    result = subprocess.run(
        ["rg", "--files", str(root)],
        check=False,
        capture_output=True,
        text=True,
    )
    files = []
    for line in result.stdout.splitlines():
        path = Path(line)
        if path.suffix.lower() in MEDIA_EXTENSIONS:
            files.append(path)
    return files


def ffprobe(path: Path) -> dict:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=codec_name,width,height,bit_rate,r_frame_rate,duration",
            "-show_entries",
            "format=duration,bit_rate,size",
            "-of",
            "json",
            str(path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return {"error": result.stderr.strip()[:200]}
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"error": "ffprobe JSON parse failed"}
    stream = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}
    return {
        "codec": stream.get("codec_name"),
        "width": int(stream["width"]) if str(stream.get("width", "")).isdigit() else None,
        "height": int(stream["height"]) if str(stream.get("height", "")).isdigit() else None,
        "fps": stream.get("r_frame_rate"),
        "stream_bitrate": int(stream["bit_rate"]) if str(stream.get("bit_rate", "")).isdigit() else None,
        "format_bitrate": int(fmt["bit_rate"]) if str(fmt.get("bit_rate", "")).isdigit() else None,
        "duration": float(fmt["duration"]) if str(fmt.get("duration", "")).replace(".", "", 1).isdigit() else None,
        "size": int(fmt["size"]) if str(fmt.get("size", "")).isdigit() else None,
    }


def bitrate_mbps(value: Optional[int]) -> str:
    if not value:
        return "unknown"
    return f"{value / 1_000_000:.1f} Mbps"


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: analyze-nas-samples.py OUTPUT.md ROOT...", file=sys.stderr)
        return 2

    output = Path(sys.argv[1])
    roots = [Path(arg) for arg in sys.argv[2:]]
    lines: list[str] = [
        "# NAS Dashcam Filename And Media Pattern Sampling",
        "",
        "Private research pass from mounted NAS footage. Filenames below are sanitized to the original camera-looking token before any human description suffix.",
        "",
    ]

    for root in roots:
        media = list_media(root)
        lines.append(f"## {root.name}")
        lines.append("")
        lines.append(f"- Media files scanned: {len(media)}")
        if not media:
            lines.append("")
            continue

        by_pattern: dict[str, list[Path]] = defaultdict(list)
        for path in media:
            by_pattern[pattern_for(raw_name(path))].append(path)

        for pattern, paths in sorted(by_pattern.items(), key=lambda item: (-len(item[1]), item[0]))[:8]:
            samples = paths[:4]
            lines.append(f"- Pattern `{pattern}`: {len(paths)} file(s)")
            lines.append("  - Examples: " + ", ".join(f"`{raw_name(path)}{path.suffix}`" for path in samples))

            for sample in samples[:2]:
                info = ffprobe(sample)
                if "error" in info:
                    lines.append(f"  - ffprobe `{raw_name(sample)}{sample.suffix}`: {info['error']}")
                    continue
                bitrate = info.get("stream_bitrate") or info.get("format_bitrate")
                resolution = "unknown"
                if info.get("width") and info.get("height"):
                    resolution = f"{info['width']}x{info['height']}"
                duration = info.get("duration")
                duration_text = f"{duration:.1f}s" if isinstance(duration, float) else "unknown"
                lines.append(
                    f"  - ffprobe `{raw_name(sample)}{sample.suffix}`: "
                    f"{resolution}, {info.get('codec') or 'unknown codec'}, "
                    f"{bitrate_mbps(bitrate)}, {duration_text}"
                )
        lines.append("")

    output.write_text("\n".join(lines), encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
