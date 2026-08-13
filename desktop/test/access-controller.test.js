const assert = require("node:assert/strict");
const test = require("node:test");
const { createAccessController, publicCopyResult } = require("../src/access-controller");

function fixture() {
  let nextID = 0;
  return createAccessController({
    realpath: async (value) => `/canonical${value}`,
    randomUUID: () => `opaque-${nextID += 1}`
  });
}

test("rejects renderer requests without approved folder capabilities", async () => {
  const access = fixture();
  await assert.rejects(() => access.scanApprovedSource("/forged/path", async () => []), /must be chosen/);
  assert.throws(() => access.createCopyPlan("forged-source", "forged-destination", () => []), /must be chosen/);
});

test("copy results do not expose source or destination paths", () => {
  const result = publicCopyResult({
    copied: 1,
    skipped: 2,
    conflicts: [{
      filename: "clip.mp4",
      reason: "Different file",
      sourcePath: "/private/source/clip.mp4",
      destinationPath: "/private/destination/clip.mp4"
    }]
  });
  assert.deepEqual(result, {
    copied: 1,
    skipped: 2,
    conflicts: [{ filename: "clip.mp4", reason: "Different file" }]
  });
  assert.equal(JSON.stringify(result).includes("/private/"), false);
});

test("returns redacted media and creates a one-use opaque copy plan", async () => {
  const access = fixture();
  const source = await access.approveFolder("source", "/source");
  const destination = await access.approveFolder("destination", "/destination");
  assert.deepEqual(source, { token: "opaque-1", displayName: "source" });
  assert.deepEqual(destination, { token: "opaque-2", displayName: "destination" });

  const media = await access.scanApprovedSource(source.token, async (sourcePath) => [{
    sourcePath: `${sourcePath}/Record/private-name.mp4`,
    relativePath: "Record/private-name.mp4",
    filename: "private-name.mp4",
    bytes: 42,
    kind: "Video"
  }]);
  assert.equal("sourcePath" in media[0], false);

  const publicPlan = access.createCopyPlan(source.token, destination.token, (sourcePath, destinationPath, storedMedia) => {
    assert.equal(sourcePath, "/canonical/source");
    assert.equal(destinationPath, "/canonical/destination");
    assert.equal(storedMedia[0].sourcePath, "/canonical/source/Record/private-name.mp4");
    return [{ sourcePath, destinationPath }];
  });
  assert.deepEqual(publicPlan, { token: "opaque-3", totalFiles: 1 });
  assert.equal(access.consumeCopyPlan(publicPlan.token).length, 1);
  assert.throws(() => access.consumeCopyPlan(publicPlan.token), /unavailable or expired/);
});
