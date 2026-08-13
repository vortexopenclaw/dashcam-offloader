const assert = require("node:assert/strict");
const EventEmitter = require("node:events");
const test = require("node:test");
const { checkForUpdates, configureUpdatePrompts } = require("../src/update-controller");

class FakeUpdater extends EventEmitter {
  constructor() { super(); this.downloads = 0; this.restarts = 0; }
  async downloadUpdate() { this.downloads += 1; }
  quitAndInstall() { this.restarts += 1; }
  async checkForUpdates() { return { updateInfo: { version: "0.2.1" } }; }
}

test("prompts before download and restart", async () => {
  const updater = new FakeUpdater();
  const prompts = [];
  const dialog = { showMessageBox: async (options) => { prompts.push(options); return { response: 0 }; } };
  configureUpdatePrompts({ updater, dialog });
  updater.emit("update-available", { version: "0.2.1" });
  await new Promise(setImmediate);
  updater.emit("update-downloaded", { version: "0.2.1" });
  await new Promise(setImmediate);
  assert.equal(updater.autoDownload, false);
  assert.equal(updater.downloads, 1);
  assert.equal(updater.restarts, 1);
  assert.equal(prompts.length, 2);
});

test("keeps update check failures non-disruptive", async () => {
  const logs = [];
  const updater = { checkForUpdates: async () => { throw new Error("offline"); } };
  assert.equal(await checkForUpdates({ updater, log: (message) => logs.push(message) }), null);
  assert.match(logs[0], /offline/);
});
