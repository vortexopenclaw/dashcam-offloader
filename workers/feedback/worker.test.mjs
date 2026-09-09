import { test } from "node:test";
import assert from "node:assert/strict";
import {
  validateFeedback,
  sanitizeFeedback,
  sanitizeScan,
  sanitizePath,
  safePathList,
  isSensitiveSettingPair,
  isSafeSettingPair,
  clientFingerprint,
} from "./worker.js";

test("validateFeedback rejects invalid kinds and empty messages", () => {
  assert.equal(validateFeedback(null).ok, false);
  assert.equal(validateFeedback({ kind: "spam", message: "hi" }).ok, false);
  assert.equal(validateFeedback({ kind: "bug", message: "   " }).ok, false);
  assert.equal(validateFeedback({ kind: "bug", message: "" }).ok, false);
  assert.equal(validateFeedback({ kind: "bug", message: "x".repeat(12001) }).ok, false);
  assert.equal(validateFeedback({ kind: "bug", message: "It crashed" }).ok, true);
});

test("validateFeedback requires complete training fields", () => {
  assert.equal(validateFeedback({ kind: "training", message: "card" }).ok, false);
  assert.equal(
    validateFeedback({ kind: "training", message: "card", training: { manufacturer: "70mai", model: "", channelSetup: "2CH" } }).ok,
    false
  );
  assert.equal(
    validateFeedback({ kind: "training", message: "card", training: { manufacturer: "70mai", model: "X800", channelSetup: "2CH front/rear" } }).ok,
    true
  );
});

test("sensitive setting pairs are detected", () => {
  assert.equal(isSensitiveSettingPair("wifi_ssid", ""), true);
  assert.equal(isSensitiveSettingPair("password", ""), true);
  assert.equal(isSensitiveSettingPair("plate_number", ""), true);
  assert.equal(isSensitiveSettingPair("serial", ""), true);
  assert.equal(isSensitiveSettingPair("gps", "47.61234"), true, "coordinate-like value must be sensitive");
  assert.equal(isSensitiveSettingPair("resolution", "3840x2160"), false);
  assert.equal(isSafeSettingPair("resolution", "3840x2160"), true);
  assert.equal(isSafeSettingPair("randomkey", "value"), false, "non-useful keys are dropped");
});

test("sanitizePath drops sensitive path segments", () => {
  assert.equal(sanitizePath("DCIM/wifi_backup/GH010001.MP4"), "DCIM/GH010001.MP4");
  assert.equal(sanitizePath("Normal/NO20260612-120000F.MP4"), "Normal/NO20260612-120000F.MP4");
});

test("safePathList drops entries containing coordinates", () => {
  const result = safePathList(["Movie/47.61234_-122.12345.mp4", "Movie/clip1.mp4"], 10);
  assert.deepEqual(result, ["Movie/clip1.mp4"]);
});

test("sanitizeScan strips unsafe setting values and keeps safe ones", () => {
  const scan = sanitizeScan({
    volumeName: "70MAI_X800",
    settingSnapshots: [
      {
        relativePath: "CONFIG/settings.ini",
        keys: ["model", "wifi_ssid"],
        safeValues: {
          model: "X800",
          resolution: "2160p",
          wifi_password: "hunter2",
          latitude: "47.61234",
        },
      },
    ],
  });
  assert.equal(scan.settingSnapshots.length, 1);
  const snapshot = scan.settingSnapshots[0];
  assert.deepEqual(Object.keys(snapshot.safeValues).sort(), ["model", "resolution"]);
  assert.deepEqual(snapshot.keys, ["model"]);
  assert.equal("volumeName" in scan, false);
  assert.equal("sampleRelativePaths" in scan, false);
  assert.equal("filenameSamples" in scan, false);
});

test("sanitizeScan drops private paths, filenames, timestamps, evidence, and diagnostics", () => {
  const scan = sanitizeScan({
    volumeName: "Personal NAS",
    identifiedCamera: {
      manufacturer: "Example",
      model: "Camera",
      evidence: ["/Users/example-user/Vacation/secret.mp4"],
      isSupported: true,
    },
    candidates: [{
      profileID: "example-camera",
      profileName: "Example Camera",
      score: 90,
      confidence: "high",
      evidence: ["Family Trip/secret.mp4"],
    }],
    scanDiagnostics: [{
      stage: "detection",
      profileID: "example-camera",
      profileName: "Example Camera",
      outcome: "matched",
      detail: "Found /Users/example-user/Vacation/secret.mp4",
    }],
    settingSnapshots: [{
      relativePath: "Private/config.ini",
      keys: ["model"],
      safeValues: { model: "Camera" },
    }],
    videoSpecSummaries: [{
      folder: "Family Trip",
      extensionLowercased: ".mp4",
      fileCount: 2,
      firstTimestamp: "2026-08-13T12:34:56Z",
      lastTimestamp: "2026-08-13T12:36:56Z",
      sampleRelativePaths: ["Family Trip/home-address.mp4"],
      sampleCodecs: ["h264"],
      sampleResolutions: ["3840x2160"],
    }],
    extensionCounts: {
      mp4: 2,
      "person@example.com": 1,
      "Private/clip": 1,
      "123e4567-e89b-12d3-a456-426614174000": 1,
    },
  });

  assert.deepEqual(scan.identifiedCamera.evidence, []);
  assert.deepEqual(scan.candidates[0].evidence, []);
  assert.equal(scan.scanDiagnostics[0].detail, "");
  assert.equal(scan.settingSnapshots[0].relativePath, "");
  assert.equal(scan.videoSpecSummaries[0].folder, ".");
  assert.equal(scan.videoSpecSummaries[0].firstTimestamp, null);
  assert.equal(scan.videoSpecSummaries[0].lastTimestamp, null);
  assert.deepEqual(scan.videoSpecSummaries[0].sampleRelativePaths, []);
  assert.deepEqual(scan.videoSpecSummaries[0].sampleCodecs, ["h264"]);
  assert.deepEqual(scan.extensionCounts, { mp4: 2 });
  assert.equal(JSON.stringify(scan).includes("secret.mp4"), false);
  assert.equal(JSON.stringify(scan).includes("Family Trip"), false);
  assert.equal(JSON.stringify(scan).includes(`/${"Users"}/`), false);
});

test("sanitizeFeedback trims message and preserves kind", () => {
  const record = sanitizeFeedback({ kind: "bug", message: "  it broke  ", contact: " a@b.c " });
  assert.equal(record.kind, "bug");
  assert.equal(record.message, "it broke");
  assert.equal(record.contact, "a@b.c");
});

test("clientFingerprint is stable and salt-dependent", async () => {
  const a1 = await clientFingerprint("203.0.113.5", "salt-one");
  const a2 = await clientFingerprint("203.0.113.5", "salt-one");
  const b = await clientFingerprint("203.0.113.5", "salt-two");
  const unknown = await clientFingerprint("unknown", "salt-one");
  assert.equal(a1, a2);
  assert.notEqual(a1, b);
  assert.match(a1, /^[0-9a-f]{64}$/);
  assert.match(unknown, /^[0-9a-f]{64}$/);
});


test("storage samples retain paired complete-file measurements without private fields", () => {
  const short = {fileSizeBytes:120000000,durationSeconds:30,width:3840,height:2160,
    nominalFrameRate:30,videoBitrate:16000000,relativePath:"private/location.mp4",
    timestamp:"private",gps:"private",storageBytesPerSecond:999};
  const scan = sanitizeScan({videoSpecSummaries:[{channel:"front",storageRateSamples:[
    short, {...short,durationSeconds:60}, {...short,durationSeconds:0},
    {...short,durationSeconds:Infinity}, {...short,fileSizeBytes:-1},
    {...short,fileSizeBytes:"120000000"}, null,
  ]}]});
  const pairs = scan.videoSpecSummaries[0].storageRateSamples;
  assert.equal(pairs.length,2);
  assert.deepEqual(pairs.map(s=>s.fileSizeBytes/s.durationSeconds),[4000000,2000000]);
  assert.equal(pairs[0].videoBitrate,16000000);
  assert.deepEqual(Object.keys(pairs[0]).sort(),[
    "fileSizeBytes","durationSeconds","width","height","nominalFrameRate","videoBitrate"
  ].sort());
  assert.deepEqual(sanitizeScan({videoSpecSummaries:[{}]}).videoSpecSummaries[0].storageRateSamples,[]);
  assert.equal(sanitizeScan({videoSpecSummaries:[{storageRateSamples:Array(100).fill(short)}]})
    .videoSpecSummaries[0].storageRateSamples.length,64);
});
