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
    video = root / "generated.mp4"
    subprocess.run([ffmpeg, "-v", "error", "-f", "lavfi", "-i",
                    "testsrc2=size=320x180:rate=30", "-t", "1", "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", str(video)], check=True)
    for label, count in [("small", 4), ("large", 140), ("structural", 1)]:
        for index in range(count):
            folder = "DCIM/inside/200video" if index % 2 else "DCIM/200video"
            name = f"N_20300102123456_{index // 2 + 1:04d}.MP4"
            target = fixture / label / folder / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if label == "structural":
                target.write_bytes(b"not a playable video")
            else:
                shutil.copyfile(video, target)
    photo = fixture / "small/DCIM/201photo/IMG_20300102_new.JPG"
    photo.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg, "-v", "error", "-i", str(video), "-frames:v", "1", str(photo)], check=True)
    before = {path: (hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_mtime_ns)
              for path in fixture.rglob("*") if path.is_file()}
    subprocess.run(["/usr/bin/swift", "run", "--build-system", "native", "--sdk",
                    "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk", "--scratch-path",
                    ".build-private", "DashcamOffloader", "--verify-private-evidence",
                    str(fixture), str(output)], cwd=repo, check=True)
    environment = dict(os.environ, DASHCAM_NATIVE_EVIDENCE_OUTPUT=str(output))
    subprocess.run([node, "--test", "workers/feedback/private-evidence.test.mjs"],
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
