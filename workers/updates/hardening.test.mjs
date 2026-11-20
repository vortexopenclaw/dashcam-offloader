import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "./worker.js";

const manifest = { assetName: "Dashcam-Offloader-current.zip", assetKey: "dashcam-offloader/releases/Dashcam-Offloader-current.zip" };
const env = {
  UPDATES_BUCKET: {
    async get(key) {
      return key === "dashcam-offloader/latest.json"
        ? { body: JSON.stringify(manifest), httpEtag: '"m"', json: async () => manifest, writeHttpMetadata() {} }
        : { body: "archive bytes", httpEtag: '"a"', writeHttpMetadata() {} };
    },
  },
};

test("malformed percent-encoding in a download name is a 404, not an unhandled exception", async () => {
  for (const suffix of ["%", "%E0%A4%A", "%zz.zip", "Dashcam%2"]) {
    const response = await worker.fetch(new Request(`https://updates.example/dashcam-offloader/download/${suffix}`), env);
    assert.equal(response.status, 404, suffix);
  }
});

test("only the current archive name is served and encoded separators are refused", async () => {
  const ok = await worker.fetch(new Request("https://updates.example/dashcam-offloader/download/Dashcam-Offloader-current.zip"), env);
  assert.equal(ok.status, 200);
  for (const suffix of ["..%2Flatest.json", "%2e%2e%2flatest.json", "old.zip", "a%5Cb.zip"]) {
    const response = await worker.fetch(new Request(`https://updates.example/dashcam-offloader/download/${suffix}`), env);
    assert.equal(response.status, 404, suffix);
  }
});
