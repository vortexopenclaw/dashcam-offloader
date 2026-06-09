#!/usr/bin/env python3
"""Summarize mounted dashcam cards without modifying source media."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


VIDEO_SUFFIXES = {".mp4", ".mov"}
SKIP_PARTS = {
    ".Spotlight-V100",
    ".fseventsd",
    ".Trashes",
    ".TemporaryItems",
    ".DS_Store",
}
SENSITIVE_RE = re.compile(
    r"pass|password|pwd|ssid|wifi|mac|serial|uid|token|key|account|email|gps|"
    r"coord|lat|lon|license|plate|imei|imsi|modem",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CardSpec:
    label: str
    model: str
    path: Path
    parser: str
    config_paths: tuple[str, ...]


@dataclass(frozen=True)
class ClipInfo:
    path: Path
    rel: str
    mode: str
    channel: str


DEFAULT_CARDS = [
    CardSpec(
        "a229-pro",
        "VIOFO A229 Pro",
        Path("/Volumes/Untitled"),
        "viofo",
        ("format.txt",),
    ),
    CardSpec(
        "vueroid-s1-4k",
        "Vueroid S1 4K Infinite",
        Path("/Volumes/S1-4K"),
        "vueroid",
        ("CONFIG/config.bin",),
    ),
    CardSpec(
        "thinkware-u3000-pro",
        "Thinkware U3000 Pro",
        Path("/Volumes/U3000Pro"),
        "thinkware",
        (
            "SETTING/default.cfg",
            "SETTING/setup.cfg",
            "SETTING/lang/ver.dat",
            "SETTING/TW_SERVER_INFO.txt",
        ),
    ),
    CardSpec(
        "a329s",
        "VIOFO A329S",
        Path("/Volumes/A329S"),
        "viofo",
        ("format.txt",),
    ),
    CardSpec(
        "blackvue-dr970x-lte-plus",
        "BlackVue DR970X LTE Plus",
        Path("/Volumes/BLACKVUE"),
        "blackvue",
        (
            "BlackVue/Config/version.bin",
            "BlackVue/Config/micom_version.bin",
        ),
    ),
    CardSpec(
        "escort-maxcam-360c",
        "Escort MAXcam 360c",
        Path("/Volumes/NO NAME"),
        "escort_maxcam",
        (),
    ),
]


def is_skipped(path: Path) -> bool:
    return any(part in SKIP_PARTS or part.startswith("._") for part in path.parts)


def raw_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return sorted(p for p in root.rglob("*") if p.is_file() and not is_skipped(p))


def ffprobe(path: Path) -> dict[str, object]:
    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_name,width,height,r_frame_rate,avg_frame_rate,bit_rate",
        "-show_entries",
        "format=duration,bit_rate,format_name",
        "-of",
        "json",
        str(path),
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return {"error": result.stderr.strip() or "ffprobe failed"}
    data = json.loads(result.stdout)
    stream = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}
    return {
        "codec": stream.get("codec_name"),
        "width": stream.get("width"),
        "height": stream.get("height"),
        "fps": rate_to_float(stream.get("avg_frame_rate") or stream.get("r_frame_rate")),
        "stream_bitrate": int(stream["bit_rate"]) if str(stream.get("bit_rate", "")).isdigit() else None,
        "format_bitrate": int(fmt["bit_rate"]) if str(fmt.get("bit_rate", "")).isdigit() else None,
        "duration": float(fmt["duration"]) if str(fmt.get("duration", "")).replace(".", "", 1).isdigit() else None,
        "container": fmt.get("format_name"),
    }


def rate_to_float(value: object) -> float | None:
    if not isinstance(value, str) or "/" not in value:
        return None
    numerator, denominator = value.split("/", 1)
    try:
        den = float(denominator)
        return round(float(numerator) / den, 3) if den else None
    except ValueError:
        return None


def bitrate_mbps(value: int | None) -> str:
    if not value:
        return "unknown"
    return f"{value / 1_000_000:.1f} Mbps"


def duration_text(value: float | None) -> str:
    if value is None:
        return "unknown"
    return f"{value:.1f}s"


def mode_from_viofo(path: Path, rel: str, channel: str) -> str:
    parts = {part.lower() for part in Path(rel).parts[:-1]}
    if "ro" in parts:
        return "locked"
    if "parking" in parts or channel.startswith("P"):
        return "parking"
    return "driving"


def parse_viofo(root: Path, path: Path) -> ClipInfo | None:
    rel = path.relative_to(root).as_posix()
    match = re.search(r"_(?P<seq>\d+)(?P<channel>PF|PI|PR|F|I|R)\.(?:MP4|mp4)$", path.name)
    if not match:
        return None
    channel = match.group("channel")
    return ClipInfo(path, rel, mode_from_viofo(path, rel, channel), channel)


def parse_vueroid(root: Path, path: Path) -> ClipInfo | None:
    rel = path.relative_to(root).as_posix()
    match = re.match(
        r"\d{8}_\d{6}_(?P<token>[A-Z]+)_(?P<channel>[FRI])_[A-Z]\.(?:mp4|MP4)$",
        path.name,
    )
    if not match:
        return None
    folder = Path(rel).parts[0].upper()
    mode_map = {
        "INF": "driving",
        "PARK": "parking",
        "EVENT": "event",
        "USER": "manual",
        "PEVENT": "parking_event",
        "BOOKMARK": "bookmark",
    }
    return ClipInfo(path, rel, mode_map.get(folder, folder.lower()), match.group("channel"))


def parse_thinkware(root: Path, path: Path) -> ClipInfo | None:
    rel = path.relative_to(root).as_posix()
    match = re.match(
        r"(?P<prefix>[A-Z]+)_\d{8}_\d{6}_(?P<channel>F|R|I)(?:_[A-Z]+)?\.(?:MP4|mp4)$",
        path.name,
    )
    if not match:
        return None
    folder = Path(rel).parts[0].lower()
    mode_map = {
        "cont_rec": "driving",
        "evt_rec": "event",
        "manual_rec": "manual",
        "parking_rec": "parking_event",
        ".parking_rec_sec": "parking_secondary",
        "motion_timelapse_rec": "parking_motion_or_timelapse",
        "sos_rec": "sos",
        "incabin_rec": "incabin",
    }
    return ClipInfo(path, rel, mode_map.get(folder, match.group("prefix").lower()), match.group("channel"))


def parse_blackvue(root: Path, path: Path) -> ClipInfo | None:
    rel = path.relative_to(root).as_posix()
    match = re.match(
        r"\d{8}_\d{6}_(?P<mode>[NPI])(?P<channel>[FR])\.(?:mp4|MP4)$",
        path.name,
    )
    if not match:
        return None
    mode_map = {
        "N": "driving",
        "P": "parking",
        "I": "impact_event",
    }
    return ClipInfo(path, rel, mode_map[match.group("mode")], match.group("channel"))


def parse_escort_maxcam(root: Path, path: Path) -> ClipInfo | None:
    rel = path.relative_to(root).as_posix()
    if path.name == ".deleted.MOV":
        return None
    match = re.match(r"\d{8}_\d{4}_(?P<token>VID|SOS)\.(?:MOV|mov)$", path.name)
    if not match:
        return None
    mode_map = {
        "VID": "driving",
        "SOS": "locked",
    }
    return ClipInfo(path, rel, mode_map[match.group("token")], "front")


def parse_clip(card: CardSpec, path: Path) -> ClipInfo | None:
    if path.suffix.lower() not in VIDEO_SUFFIXES:
        return None
    if card.parser == "viofo":
        return parse_viofo(card.path, path)
    if card.parser == "vueroid":
        return parse_vueroid(card.path, path)
    if card.parser == "thinkware":
        return parse_thinkware(card.path, path)
    if card.parser == "blackvue":
        return parse_blackvue(card.path, path)
    if card.parser == "escort_maxcam":
        return parse_escort_maxcam(card.path, path)
    return None


def safe_strings(path: Path) -> list[str]:
    if not path.exists() or path.name == "device.uid":
        return []
    result = subprocess.run(["strings", "-n", "3", str(path)], text=True, capture_output=True, check=False)
    lines: list[str] = []
    for raw in result.stdout.splitlines():
        line = raw.strip()
        if not line or SENSITIVE_RE.search(line):
            continue
        if line not in lines:
            lines.append(line)
        if len(lines) >= 12:
            break
    return lines


def summarize_card(card: CardSpec, max_samples_per_group: int) -> str:
    files = raw_files(card.path)
    clips = [clip for path in files if (clip := parse_clip(card, path))]
    grouped: dict[tuple[str, str], list[ClipInfo]] = defaultdict(list)
    for clip in clips:
        grouped[(clip.mode, clip.channel)].append(clip)

    lines = [f"## {card.model}", "", f"- Mounted path: `{card.path}`"]
    lines.append(f"- Parsed video files: {len(clips)}")
    lines.append("- Mode/channel counts:")
    for (mode, channel), members in sorted(grouped.items()):
        lines.append(f"  - `{mode}` `{channel}`: {len(members)}")

    lines.extend(["", "### Representative ffprobe Samples", ""])
    lines.append("| Mode | Channel | Sample | Codec | Resolution | FPS | Bitrate | Duration |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for (mode, channel), members in sorted(grouped.items()):
        for clip in sorted(members, key=lambda item: item.rel)[:max_samples_per_group]:
            info = ffprobe(clip.path)
            if "error" in info:
                lines.append(f"| {mode} | {channel} | `{clip.rel}` | error |  |  | {info['error']} |  |")
                continue
            bitrate = info.get("stream_bitrate") or info.get("format_bitrate")
            resolution = (
                f"{info.get('width')}x{info.get('height')}"
                if info.get("width") and info.get("height")
                else "unknown"
            )
            fps = f"{info['fps']:.3g}" if isinstance(info.get("fps"), float) else "unknown"
            lines.append(
                f"| {mode} | {channel} | `{clip.rel}` | {info.get('codec') or 'unknown'} | "
                f"{resolution} | {fps} | {bitrate_mbps(bitrate if isinstance(bitrate, int) else None)} | "
                f"{duration_text(info.get('duration') if isinstance(info.get('duration'), float) else None)} |"
            )

    lines.extend(["", "### Safe Config Signals", ""])
    for rel in card.config_paths:
        path = card.path / rel
        if not path.exists():
            lines.append(f"- `{rel}`: not present")
            continue
        size = path.stat().st_size
        strings = safe_strings(path)
        if strings:
            lines.append(f"- `{rel}` ({size} bytes): " + "; ".join(f"`{item}`" for item in strings))
        else:
            lines.append(f"- `{rel}` ({size} bytes): no safe printable strings")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-samples-per-group", type=int, default=1)
    args = parser.parse_args()

    print("# Mounted Card Spec Pass")
    print()
    print("Read-only summary from mounted dashcam cards. Raw video files, raw config dumps, GPS traces, device IDs, Wi-Fi fields, and credentials are not copied or printed.")
    print()
    for card in DEFAULT_CARDS:
        print(summarize_card(card, args.max_samples_per_group))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
