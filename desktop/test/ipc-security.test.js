const assert = require("node:assert/strict");
const test = require("node:test");
const { assertTrustedSender } = require("../src/ipc-security");

test("accepts only the exact bundled renderer URL", () => {
  const expectedURL = "file:///Applications/Dashcam%20Offloader.app/Contents/Resources/app.asar/src/renderer/index.html";
  assert.doesNotThrow(() => assertTrustedSender({ senderFrame: { url: expectedURL } }, expectedURL));
  assert.throws(
    () => assertTrustedSender({ senderFrame: { url: "https://attacker.invalid/" } }, expectedURL),
    /did not come from/
  );
  assert.throws(() => assertTrustedSender({}, expectedURL), /did not come from/);
});
