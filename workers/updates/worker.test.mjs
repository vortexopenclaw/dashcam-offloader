import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "./worker.js";

const currentName = "Dashcam-Offloader-current.zip";
const manifest = {
  assetName: currentName,
  assetKey: `dashcam-offloader/releases/${currentName}`,
};

function environment() {
  const reads = [];
  return {
    reads,
    UPDATES_BUCKET: {
      async get(key) {
        reads.push(key);
        if (key === "dashcam-offloader/latest.json") {
          return { json: async () => manifest };
        }
        return { body: "archive bytes", writeHttpMetadata() {} };
      },
    },
  };
}

test("superseded archive URLs do not expose retained rollback data", async () => {
  const env = environment();
  const response = await worker.fetch(
    new Request("https://updates.example/dashcam-offloader/download/Dashcam-Offloader-previous.zip"),
    env,
  );
  assert.equal(response.status, 404);
  assert.deepEqual(env.reads, ["dashcam-offloader/latest.json"]);
});

test("current archive remains available by its exact name", async () => {
  const env = environment();
  const response = await worker.fetch(
    new Request(`https://updates.example/dashcam-offloader/download/${currentName}`),
    env,
  );
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "archive bytes");
  assert.equal(env.reads.at(-1), manifest.assetKey);
});

test("older installed clients can still use the latest download endpoint", async () => {
  const env = environment();
  const response = await worker.fetch(
    new Request("https://updates.example/dashcam-offloader/download/latest"),
    env,
  );
  assert.equal(response.status, 200);
  assert.equal(env.reads.at(-1), manifest.assetKey);
});
