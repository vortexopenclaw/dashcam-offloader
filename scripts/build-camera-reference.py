#!/usr/bin/env python3
"""Build the privacy-safe camera reference consumed by every desktop UI."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
PROFILE_DIR = ROOT / "profiles"
OUTPUT_PATH = ROOT / "reference" / "cameras.json"
VIDEO_METADATA_PATH = ROOT / "docs" / "video-metadata-reference.md"
GITHUB_BLOB_ROOT = "https://github.com/vortexopenclaw/dashcam-offloader/blob/main/"
URL_PATTERN = re.compile(r'https?://[^\s<>`)\]}"]+')
TECHNICAL_SECTIONS = (
    "observed_media",
    "sampled_recording_settings",
    "video",
    "resolutions",
    "recording",
    "recording_modes",
    "parking_mode",
    "multiplexed_video",
    "firmware",
    "grouping",
)
PRIVATE_KEYS = {
    "serial",
    "serial_number",
    "device_id",
    "device_identifier",
    "gps_coordinates",
    "latitude",
    "longitude",
    "ssid",
    "password",
    "cloud_credentials",
}
PRIVATE_OUTPUT_PATTERNS = {
    "local volume path": re.compile(r"/Volumes/"),
    "personal home path": re.compile(r"(?:/Users/|/home/|C:\\\\Users\\\\)"),
    "submission identifier": re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", re.I),
    "private IPv4 address": re.compile(r"(?<![a-z0-9])(?:192\.168|10|172\.(?:1[6-9]|2[0-9]|3[01]))(?:\.[0-9]{1,3}){2,3}(?![a-z0-9])", re.I),
    "private owner name": re.compile(r"\bAriel(?:\s+Bravy)?\b", re.I),
}


def load_profile(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path.name}: profile root must be a mapping")
    return data


def text(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return "Yes" if value else "No"
    if isinstance(value, (str, int, float)):
        result = str(value).strip()
        return result or None
    if isinstance(value, list) and all(not isinstance(item, (dict, list)) for item in value):
        return ", ".join(str(item) for item in value)
    return None


def flatten_facts(value: Any, path: list[str], output: list[dict[str, str]]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = str(key).lower()
            if normalized in PRIVATE_KEYS or normalized in {"notes", "note"}:
                continue
            flatten_facts(child, path + [str(key)], output)
        return
    if isinstance(value, list):
        for index, child in enumerate(value, start=1):
            if isinstance(child, dict):
                context = (
                    child.get("position")
                    or child.get("channel")
                    or child.get("folder")
                    or f"Sample {index}"
                )
                flatten_facts(child, path + [str(context)], output)
            else:
                flattened = text(child)
                if flattened:
                    output.append({"label": " › ".join(path), "value": flattened})
        return
    flattened = text(value)
    if flattened:
        output.append({"label": " › ".join(path), "value": flattened})


def notes_from(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    if isinstance(value, list):
        return [str(item).strip() for item in value if isinstance(item, (str, int, float)) and str(item).strip()]
    return []


def source_note_paths(profile: dict[str, Any]) -> list[str]:
    notes = profile.get("source_notes", [])
    if not isinstance(notes, list):
        return []
    return [item for item in notes if isinstance(item, str) and item.startswith("docs/") and item.endswith(".md")]


def links_for(profile: dict[str, Any]) -> list[dict[str, str]]:
    links: list[dict[str, str]] = []
    manual_reference = profile.get("manual_reference")
    if isinstance(manual_reference, dict) and isinstance(manual_reference.get("url"), str):
        links.append({"label": "Official manual", "url": manual_reference["url"], "kind": "manual"})

    for relative_path in source_note_paths(profile):
        doc_path = ROOT / relative_path
        links.append({
            "label": doc_path.stem.replace("-", " ").title() + " research notes",
            "url": GITHUB_BLOB_ROOT + relative_path,
            "kind": "research",
        })
        if not doc_path.is_file():
            continue
        for line in doc_path.read_text(encoding="utf-8").splitlines():
            for url in URL_PATTERN.findall(line):
                lowered = line.lower()
                is_manual = "manual" in lowered or url.lower().endswith(".pdf")
                links.append({
                    "label": "Official manual" if is_manual else "Reference source",
                    "url": url.rstrip(".,;"),
                    "kind": "manual" if is_manual else "source",
                })

    deduplicated: list[dict[str, str]] = []
    seen: set[str] = set()
    for link in links:
        if link["url"] not in seen:
            seen.add(link["url"])
            deduplicated.append(link)
    return deduplicated


def folders_for(profile: dict[str, Any]) -> list[dict[str, Any]]:
    result = []
    for folder in profile.get("folders", []) or []:
        if not isinstance(folder, dict) or not folder.get("path"):
            continue
        result.append({
            "path": str(folder["path"]),
            "mode": str(folder.get("mode", "recording")),
            "importable": folder.get("import", True) is not False,
            "validation": text(folder.get("validation")),
            "notes": notes_from(folder.get("notes") or folder.get("note")),
        })
    return result


def filename_patterns_for(profile: dict[str, Any]) -> list[dict[str, Any]]:
    result = []
    patterns = profile.get("filename_patterns", profile.get("filename_pattern", [])) or []
    if isinstance(patterns, dict):
        patterns = [patterns]
    for pattern in patterns:
        if not isinstance(pattern, dict):
            continue
        raw = pattern.get("pattern") or pattern.get("regex")
        if not raw:
            continue
        timestamp = pattern.get("timestamp")
        result.append({
            "pattern": str(raw),
            "appliesTo": [str(item) for item in pattern.get("applies_to", []) or []],
            "modes": {str(key): str(value) for key, value in (pattern.get("modes", {}) or {}).items()},
            "channels": {str(key): str(value) for key, value in (pattern.get("channels", {}) or {}).items()},
            "defaultChannel": text(pattern.get("default_channel")),
            "timestampFormat": text(timestamp.get("format")) if isinstance(timestamp, dict) else None,
        })
    return result


def channel_variants_for(profile: dict[str, Any]) -> list[dict[str, Any]]:
    variants = profile.get("channel_variants") or []
    if not variants and isinstance(profile.get("channels"), int):
        variants = [{"channels": profile["channels"], "roles": [], "validation": profile.get("status")}]
    result = []
    for variant in variants:
        if not isinstance(variant, dict):
            continue
        result.append({
            "channels": variant.get("channels"),
            "variant": text(variant.get("variant")),
            "roles": [str(role) for role in variant.get("roles", []) or []],
            "validation": text(variant.get("validation")),
        })
    return result


def reference_name_key(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]", "", value.lower())
    for removable in ("standardedition", "2ch", "3ch"):
        normalized = normalized.replace(removable, "")
    return normalized


def video_metadata() -> dict[str, tuple[str, list[dict[str, str]]]]:
    if not VIDEO_METADATA_PATH.is_file():
        return {}
    result: dict[str, tuple[str, list[dict[str, str]]]] = {}
    current_name: str | None = None
    rows: list[dict[str, str]] = []

    def flush() -> None:
        if current_name and rows:
            result[reference_name_key(current_name)] = (current_name, list(rows))

    for line in VIDEO_METADATA_PATH.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            flush()
            current_name = line[3:].strip()
            rows = []
            continue
        if not current_name or not line.startswith("|"):
            continue
        columns = [column.strip().strip("`") for column in line.strip().strip("|").split("|")]
        if len(columns) != 8 or columns[0] in {"Channel", "Source"} or set(columns[0]) == {"-"}:
            continue
        rows.append({
            "channel": columns[0],
            "mode": columns[1],
            "codec": columns[2],
            "resolution": columns[3],
            "fps": columns[4],
            "bitrate": columns[5],
            "container": columns[6],
            "source": columns[7],
        })
    flush()
    return result


def camera_record(path: Path, profile: dict[str, Any], samples: list[dict[str, str]]) -> dict[str, Any]:
    technical_facts: list[dict[str, str]] = []
    for section in TECHNICAL_SECTIONS:
        if section in profile:
            flatten_facts(profile[section], [section], technical_facts)

    parking_modes = []
    parking = profile.get("parking_mode")
    if isinstance(parking, dict) and isinstance(parking.get("observed"), list):
        parking_modes = [str(item) for item in parking["observed"]]

    return {
        "id": str(profile.get("id") or path.stem),
        "manufacturer": str(profile.get("manufacturer") or profile.get("make") or "Unknown"),
        "model": str(profile.get("model") or path.stem),
        "status": str(profile.get("status") or "seed"),
        "confidence": str(profile.get("confidence") or "not stated"),
        "confidenceNote": text(profile.get("confidence_note")),
        "channelVariants": channel_variants_for(profile),
        "folders": folders_for(profile),
        "filenamePatterns": filename_patterns_for(profile),
        "technicalFacts": technical_facts,
        "videoSamples": samples,
        "parkingModes": parking_modes,
        "sourceLinks": links_for(profile),
        "notes": notes_from(profile.get("notes")),
    }


def build() -> dict[str, Any]:
    metadata = video_metadata()
    cameras = []
    matched_metadata: set[str] = set()
    for path in sorted(PROFILE_DIR.glob("*.yaml")):
        profile = load_profile(path)
        manufacturer = profile.get("manufacturer") or profile.get("make") or "Unknown"
        model = profile.get("model") or path.stem
        key = reference_name_key(f"{manufacturer} {model}")
        samples = metadata.get(key, ("", []))[1]
        if samples:
            matched_metadata.add(key)
        cameras.append(camera_record(path, profile, samples))

    for key, (display_name, samples) in metadata.items():
        if key in matched_metadata or not samples:
            continue
        manufacturer, _, model = display_name.partition(" ")
        cameras.append({
            "id": "metadata-only-" + re.sub(r"[^a-z0-9]+", "-", display_name.lower()).strip("-"),
            "manufacturer": manufacturer,
            "model": model,
            "status": "reference_only",
            "confidence": "measured sample",
            "confidenceNote": "Measured video metadata is available, but a complete card folder and filename profile has not been added yet.",
            "channelVariants": [],
            "folders": [],
            "filenamePatterns": [],
            "technicalFacts": [],
            "videoSamples": samples,
            "parkingModes": [],
            "sourceLinks": [{
                "label": "Video metadata reference",
                "url": GITHUB_BLOB_ROOT + "docs/video-metadata-reference.md",
                "kind": "research",
            }],
            "notes": [],
        })
    cameras.sort(key=lambda camera: (camera["manufacturer"].lower(), camera["model"].lower()))
    return {"schemaVersion": 1, "cameras": cameras}


def assert_public_safe(payload: dict[str, Any]) -> None:
    serialized = json.dumps(payload, sort_keys=True)
    for label, pattern in PRIVATE_OUTPUT_PATTERNS.items():
        if pattern.search(serialized):
            raise ValueError(f"generated camera reference contains {label}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    args = parser.parse_args()
    payload = build()
    assert_public_safe(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload['cameras'])} camera references to {args.output}")


if __name__ == "__main__":
    main()
