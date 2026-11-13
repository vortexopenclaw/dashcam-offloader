import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("ingest", Path(__file__).with_name("ingest-submitted-scans.py"))
ingest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ingest)


class IngestTests(unittest.TestCase):
    def test_derive_drops_private_fields_and_marks_uncertainty(self):
        key = "feedback/2026-09-30/62d071f9-1135-4be4-8aac-1dc00f95987e.json"
        record = {"receivedAt": "2026-09-30T19:48:08.972Z", "contact": "secret@example.com",
                  "payload": {"message": "private note", "training": {"model": "T340", "manufacturer": "VIOFO"},
                              "scan": {"channelCounts": {"unknown": 81},
                                       "filenameSamples": ["2026_0930_121758_000266T.MP4", "private/Jane.mp4"],
                                       "videoSpecSummaries": [{"channel": "unknown", "mode": "parking_continuous_low_bitrate",
                                                               "sampleResolutions": ["2560x1440"], "sampleBitrateMin": 8190472,
                                                               "relativePath": "/private/path"}]}}}
        result = ingest.derive(key, record)
        encoded = json.dumps(result)
        self.assertNotIn("secret@example.com", encoded)
        self.assertNotIn("private", encoded)
        self.assertEqual(result["filenameSamples"], ["2026_0930_121758_000266T.MP4"])
        self.assertEqual(len(result["reviewFlags"]), 2)
        self.assertIsNone(ingest.derive("rate/abc", record))

    def test_pagination_dedup_and_skip_non_scan(self):
        key = "feedback/2026-09-30/62d071f9-1135-4be4-8aac-1dc00f95987e.json"
        calls = []
        def fetch(suffix):
            calls.append(suffix)
            if suffix.startswith("/keys?"):
                if "cursor=" in suffix:
                    return {"result": [{"name": key}, {"name": "feedback/2026-09-30/ee2e54e6-4099-441f-9927-192c2dc80229.json"}], "result_info": {}}
                return {"result": [{"name": key}, {"name": "rate-limit/123"}], "result_info": {"cursor": "next"}}
            if "ee2e" in suffix:
                return {"payload": {"training": {"model": "T340"}}}
            return {"payload": {"scan": {"scannedFiles": 387, "mediaExtensionCounts": {"mp4": 371, "jpg": 16}}}}
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            self.assertEqual(ingest.run(output, fetch), 1)
            self.assertEqual(ingest.run(output, fetch), 0)
            self.assertEqual(len(list(output.glob("*.json"))), 1)
            self.assertEqual(json.loads(next(output.glob("*.json")).read_text())["scannedFiles"], 387)
        self.assertTrue(any("cursor=next" in call for call in calls))

    def test_retains_paired_storage_and_video_rates_without_private_fields(self):
        key = "feedback/2026-10-01/00000000-0000-0000-0000-000000000000.json"
        sample = {"fileSizeBytes": 405000000, "durationSeconds": 60,
                  "videoBitrate": 53200000, "width": 3840, "height": 2160,
                  "relativePath": "Camera/Private/clip.mp4", "gps": "secret"}
        groups = [{"mode": "continuous", "channel": "front",
                   "storageRateSamples": [sample, dict(sample, durationSeconds=0)]}]
        groups.extend({"mode": "parking", "channel": "rear"} for _ in range(119))
        result = ingest.derive(key, {"scan": {"videoSpecSummaries": groups}})
        self.assertEqual(len(result["videoSpecSummaries"]), 120)
        pair = result["videoSpecSummaries"][0]["storageRateSamples"]
        self.assertEqual(pair, [{"fileSizeBytes": 405000000, "durationSeconds": 60,
                                 "width": 3840, "height": 2160,
                                 "nominalFrameRate": None, "videoBitrate": 53200000, "codec": None}])
        self.assertNotIn("Camera/Private", json.dumps(result))
        self.assertNotIn("secret", json.dumps(result))

    def test_private_identity_links_survive_and_unsafe_links_do_not_drop_pairs(self):
        key = "feedback/2030-01-01/00000000-0000-0000-0000-000000000000.json"
        pair = {"fileSizeBytes": 100, "durationSeconds": 1, "filename": "N_20300102123456_0001.MP4",
                "sourceIdentifier": "source-1", "folder": "DCIM/inside/200video"}
        other = dict(pair, sourceIdentifier="source-2", folder="DCIM/200video")
        bad = dict(pair, filename="../secret.MP4")
        result = ingest.derive(key, {"scan": {"filenameSamples": [pair["filename"]],
            "videoSpecSummaries": [{"channel": "telephoto", "mode": "parking", "storageRateSamples": [pair, other, bad]}]}})
        retained = result["videoSpecSummaries"][0]["storageRateSamples"]
        self.assertEqual(result["filenameSamples"], [pair["filename"]])
        for expected, actual in zip([pair, other], retained):
            for field in ["filename", "folder", "sourceIdentifier", "fileSizeBytes", "durationSeconds"]:
                self.assertEqual(actual[field], expected[field])
        self.assertEqual(len(retained), 3)
        self.assertNotIn("filename", retained[2])
        self.assertEqual(retained[2]["fileSizeBytes"], 100)


if __name__ == "__main__":
    unittest.main()
