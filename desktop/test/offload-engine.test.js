const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { executeCopy, planCopy, scanSource } = require("../src/offload-engine");

async function fixture() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "dashcam-offloader-"));
  const source = path.join(root, "source");
  const destination = path.join(root, "destination");
  await fs.mkdir(path.join(source, "Record"), { recursive: true });
  await fs.mkdir(path.join(source, "Event"), { recursive: true });
  await fs.writeFile(path.join(source, "Record", "front.mp4"), "front-video");
  await fs.writeFile(path.join(source, "Event", "front.mp4"), "event-video");
  await fs.writeFile(path.join(source, "Record", "notes.txt"), "do not copy");
  await fs.writeFile(path.join(source, ".hidden.mp4"), "do not copy");
  return { root, source, destination };
}

test("scans only eligible visible media", async (t) => {
  const { root, source } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  assert.equal(media.length, 2);
  assert.deepEqual(media.map((item) => item.relativePath), [path.join("Event", "front.mp4"), path.join("Record", "front.mp4")]);
});

test("rejects a destination inside the source", async (t) => {
  const { root, source } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  assert.throws(() => planCopy(source, path.join(source, "downloads"), media), /outside the source/);
});

test("copies, verifies, skips identical files, and preserves conflicts", async (t) => {
  const { root, source, destination } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);
  assert.equal((await executeCopy(plan)).copied, 2);
  assert.equal((await executeCopy(plan)).skipped, 2);
  await fs.writeFile(plan[0].destinationPath, "not-the-source");
  const result = await executeCopy(plan);
  assert.equal(result.copied, 0);
  assert.equal(result.conflicts.length, 1);
  assert.equal(await fs.readFile(plan[0].destinationPath, "utf8"), "not-the-source");
});
