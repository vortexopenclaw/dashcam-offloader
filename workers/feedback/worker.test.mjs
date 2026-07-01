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
