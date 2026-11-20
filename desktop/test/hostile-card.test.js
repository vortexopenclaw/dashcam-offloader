const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { executeCopy, isPathWithin, planCopy, scanSource } = require("../src/offload-engine");

async function fixture() {
  const root = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), "dashcam-offloader-hostile-")));
  const source = path.join(root, "card");
  const destination = path.join(root, "destination");
  const outside = path.join(root, "outside");
  await fs.mkdir(path.join(source, "Record"), { recursive: true });
  await fs.mkdir(destination);
  await fs.mkdir(outside);
  await fs.writeFile(path.join(source, "Record", "front.mp4"), "front-video");
  await fs.writeFile(path.join(outside, "secret.mp4"), "HOST-SECRET");
  return { root, source, destination, outside };
}

async function listTree(directory) {
  const names = [];
  for (const entry of await fs.readdir(directory, { withFileTypes: true, recursive: true })) {
    names.push(path.relative(directory, path.join(entry.parentPath ?? entry.path, entry.name)));
  }
  return names.sort();
}

const symlinkTest = process.platform === "win32" ? test.skip : test;

symlinkTest("scan ignores symlinked files and directories planted on a card", async (t) => {
  const { root, source, outside } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  await fs.symlink(path.join(outside, "secret.mp4"), path.join(source, "Record", "link.mp4"));
  await fs.symlink(outside, path.join(source, "LinkedFolder"));
  const media = await scanSource(source);
  assert.deepEqual(media.map((item) => item.relativePath), [path.join("Record", "front.mp4")]);
});

symlinkTest("does not copy a source file that became a symlink after the scan", async (t) => {
  const { root, source, destination, outside } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);

  // Swap the reviewed clip for a link to a file outside the approved source.
  const clip = path.join(source, "Record", "front.mp4");
  await fs.rm(clip);
  await fs.writeFile(path.join(outside, "secret.mp4"), "HOST-SECRET".padEnd(11));
  await fs.symlink(path.join(outside, "secret.mp4"), clip);

  const result = await executeCopy(plan);
  assert.equal(result.copied, 0);
  assert.equal(result.conflicts.length, 1);
  assert.deepEqual(await listTree(destination), ["Record"]);
});

symlinkTest("does not copy through a source folder that became a symlink after the scan", async (t) => {
  const { root, source, destination, outside } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);

  await fs.rm(path.join(source, "Record"), { recursive: true });
  await fs.writeFile(path.join(outside, "front.mp4"), "front-video");
  await fs.symlink(outside, path.join(source, "Record"));

  const result = await executeCopy(plan);
  assert.equal(result.copied, 0);
  assert.equal(result.conflicts.length, 1);
  assert.deepEqual(await listTree(destination), ["Record"]);
});

symlinkTest("does not write through a symlinked folder that leaves the chosen destination", async (t) => {
  const { root, source, destination, outside } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);

  await fs.symlink(outside, path.join(destination, "Record"));
  const before = await listTree(outside);

  const result = await executeCopy(plan);
  assert.equal(result.copied, 0);
  assert.equal(result.conflicts.length, 1);
  assert.deepEqual(await listTree(outside), before);
});

symlinkTest("does not write back onto the source through a destination symlink", async (t) => {
  const { root, source, destination } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  await fs.mkdir(path.join(source, "Event"));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);

  await fs.symlink(path.join(source, "Event"), path.join(destination, "Record"));
  const result = await executeCopy(plan);
  assert.equal(result.copied, 0);
  assert.deepEqual(await fs.readdir(path.join(source, "Event")), []);
});

symlinkTest("does not hang on a clip that was replaced by a named pipe after the scan", async (t) => {
  const { root, source, destination } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);
  const clip = path.join(source, "Record", "front.mp4");
  await fs.rm(clip);
  require("node:child_process").execFileSync("mkfifo", [clip]);

  const result = await Promise.race([
    executeCopy(plan),
    new Promise((resolve) => setTimeout(() => resolve("hung"), 1500).unref())
  ]);
  assert.notEqual(result, "hung");
  assert.equal(result.copied, 0);
  assert.equal(result.conflicts.length, 1);
});

test("a source file that changed after the scan is not reported as verified", async (t) => {
  const { root, source, destination } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);
  await fs.writeFile(path.join(source, "Record", "front.mp4"), "front-video-with-more-bytes");

  await assert.rejects(() => executeCopy(plan), /did not verify/);
  assert.deepEqual(await listTree(destination), ["Record"]);
});

test("one unsafe item does not stop the remaining verified copies", async (t) => {
  const { root, source, destination } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  await fs.mkdir(path.join(source, "Event"));
  await fs.writeFile(path.join(source, "Event", "event.mp4"), "event-video");
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);
  await fs.rm(path.join(source, "Event", "event.mp4"));

  const result = await executeCopy(plan);
  assert.equal(result.copied, 1);
  assert.equal(result.conflicts.length, 1);
  assert.equal(await fs.readFile(path.join(destination, "Record", "front.mp4"), "utf8"), "front-video");
});

test("hostile names cannot leave the destination", async (t) => {
  const { root, source, destination } = await fixture();
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const hostile = [
    "..\\..\\escape.mp4",
    "a:b|c?.mp4",
    " lead and trail .mp4",
    `${"x".repeat(200)}.mp4`,
    "new\nline\u0007.mp4",
    "-rf.mp4",
    "$(touch pwned).mp4"
  ].filter((name) => process.platform !== "win32" || !/[<>:"|?*\u0000-\u001f\\]/.test(name)); // Windows can't create these names
  for (const name of hostile) await fs.writeFile(path.join(source, "Record", name), name);
  const media = await scanSource(source);
  const plan = planCopy(source, destination, media);
  for (const item of plan) assert.equal(isPathWithin(item.destinationPath, destination), true);
  const result = await executeCopy(plan);
  // front.mp4 from the fixture plus every hostile name except dot-prefixed ones, which are hidden and never planned.
  assert.equal(media.length, 1 + hostile.filter((name) => !name.startsWith(".")).length);
  assert.equal(result.copied + result.conflicts.length, media.length);
  for (const name of await listTree(root)) {
    assert.equal(name.startsWith("card") || name.startsWith("destination") || name.startsWith("outside"), true, name);
  }
  assert.deepEqual((await fs.readdir(source)).sort(), ["Record"]);
});

test("planned media cannot be redirected with traversal segments", () => {
  const source = path.resolve("/card");
  const destination = path.resolve("/downloads");
  for (const relativePath of ["../escape.mp4", path.join("Record", "..", "..", "escape.mp4"), "", "."]) {
    assert.throws(() => planCopy(source, destination, [{
      sourcePath: path.join(source, "Record", "clip.mp4"),
      relativePath,
      filename: "clip.mp4",
      bytes: 1,
      kind: "Video"
    }]), /cannot be used safely/);
  }
});

test("containment treats another Windows drive as outside", () => {
  assert.equal(isPathWithin("C:\\Users\\me\\Videos", "E:\\", path.win32), false);
  assert.equal(isPathWithin("E:\\DCIM\\clip.mp4", "E:\\", path.win32), true);
  assert.equal(isPathWithin("E:\\..data\\clip.mp4", "E:\\", path.win32), true);
  assert.equal(isPathWithin("/card/../other", "/card", path.posix), false);
  assert.equal(isPathWithin("/card/..hidden/clip.mp4", "/card", path.posix), true);
});
