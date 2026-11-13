#!/usr/bin/env python3
"""Run under check-scratch-budget.py. Synthetic media only; no production requests."""
import os
import importlib.util
import json
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
ffmpeg = shutil.which("ffmpeg")
node = shutil.which("node")
assert ffmpeg and node, "ffmpeg and node are required for this developer-only regression"
with tempfile.TemporaryDirectory(prefix="private-evidence-", dir=repo) as temporary:
    root = Path(temporary)
    fixture = root / "fixtures"
    fixture.mkdir()
    output = root / "output"
    output.mkdir()
    (fixture / "synthetic-fixture.txt").write_text("synthetic private evidence fixture\n")
    shutil.copyfile(repo / "workers/feedback/media-basename-cases.json", fixture / "media-basename-cases.json")
    shutil.copyfile(repo / "workers/feedback/ddpai-device-info.fixture.json", fixture / "ddpai-device-info.fixture.json")
    video = root / "generated.mp4"
    subprocess.run([ffmpeg, "-v", "error", "-f", "lavfi", "-i",
                    "testsrc2=size=320x180:rate=30", "-t", "1", "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", str(video)], check=True)
    for label, count in [("small", 4), ("large", 140), ("structural", 1)]:
        for index in range(count):
            folder = "DCIM/inside/200video" if index % 2 else "DCIM/200video"
            name = f"N_20300102123456_{index // 2 + 1:04d}.MP4"
            if label == "small" and index >= 2:
                name = ["camera+token2030.MP4", "new(1).MP4"][index - 2]
            target = fixture / label / folder / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if label == "structural":
                target.write_bytes(b"not a playable video")
            else:
                shutil.copyfile(video, target)
    photo = fixture / "small/DCIM/201photo/照片2030.jpg"
    photo.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg, "-v", "error", "-i", str(video), "-frames:v", "1", str(photo)], check=True)
    before = {path: (hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_mtime_ns)
              for path in fixture.rglob("*") if path.is_file()}
    swift = ["/usr/bin/swift", "run", "--build-system",
             os.environ.get("DASHCAM_SWIFT_BUILD_SYSTEM", "swiftbuild")]
    if os.environ.get("DASHCAM_SWIFT_SDK"):
        swift += ["--sdk", os.environ["DASHCAM_SWIFT_SDK"]]
    subprocess.run(swift + ["--scratch-path", ".build-private", "DashcamOffloader",
                           "--verify-private-evidence", str(fixture), str(output)],
                   cwd=repo, check=True)
    environment = dict(os.environ, DASHCAM_NATIVE_EVIDENCE_OUTPUT=str(output), DASHCAM_DDPAI_METADATA_OUTPUT=str(output))
    subprocess.run([node, "--test", "workers/feedback/private-evidence.test.mjs", "workers/feedback/ddpai-metadata.test.mjs", "workers/feedback/discovery.test.mjs"],
                   cwd=repo, env=environment, check=True)
    for path, evidence in before.items():
        assert (hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_mtime_ns) == evidence
    def load(name):
        spec = importlib.util.spec_from_file_location(name, repo / "scripts" / (name + ".py"))
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    ingest = load("ingest-submitted-scans")
    cases = json.loads((fixture / "media-basename-cases.json").read_text())
    for name in cases["accepted"]:
        assert ingest.safe_media(name), repr(name)
    for name in cases["rejected"]:
        assert not ingest.safe_media(name), repr(name)
    rates = load("scan-storage-rates")
    for label in ["small", "large", "structural"]:
        stored = json.loads((output / (label + "-stored.json")).read_text())
        derived = ingest.derive("feedback/2030-01-01/00000000-0000-0000-0000-000000000000.json", stored)
        pairs = lambda scan: [p for group in scan["videoSpecSummaries"] for p in group["storageRateSamples"]]
        assert pairs(derived) == pairs(stored["scan"])
        assert derived["evidenceCounts"] == stored["scan"]["evidenceCounts"]
        assert {sample["sourceIdentifier"] for sample in derived["mediaFileSamples"]} == {
            sample["sourceIdentifier"] for sample in stored["scan"]["mediaFileSamples"]}
        anonymous = rates.extract(stored)
        text = json.dumps(anonymous)
        for private in ["source-", "N_20300102", "200video", "inside", "filename", "sourceIdentifier"]:
            assert private not in text
        driving = [p for group in stored["scan"]["videoSpecSummaries"] if group["mode"] == "continuous" for p in group["storageRateSamples"]]
        assert len(anonymous["completeFileSamples"]) == len(driving)
    print("PRIVATE INGEST / ANONYMOUS NUMERIC EXPORT PASS; source hashes and mtimes unchanged")
