const state = { sourcePath: null, destinationPath: null, media: [] };
const byId = (id) => document.getElementById(id);
const setStatus = (text, warning = false) => { const node = byId("status"); node.textContent = text; node.className = warning ? "warning" : ""; };

function updateDownloadButton() {
  byId("download-button").disabled = !(state.sourcePath && state.destinationPath && state.media.length);
}

function renderMedia() {
  const items = byId("items");
  items.replaceChildren(...state.media.map((item) => {
    const entry = document.createElement("li");
    entry.textContent = `${item.kind}: ${item.relativePath} (${(item.bytes / 1024 / 1024).toFixed(1)} MB)`;
    return entry;
  }));
  byId("summary").textContent = `${state.media.length} eligible media file${state.media.length === 1 ? "" : "s"} found. Hidden/system files and non-media files are excluded.`;
}

byId("update-button").addEventListener("click", async () => {
  setStatus("Checking for updates...");
  await window.offloader.checkForUpdates();
  setStatus("Update check completed. You will be prompted if an update is available.");
});

byId("source-button").addEventListener("click", async () => {
  const selected = await window.offloader.chooseFolder("Choose a memory card or video folder");
  if (!selected) return;
  state.sourcePath = selected;
  byId("source-path").textContent = selected;
  setStatus("Scanning source...");
  try {
    state.media = await window.offloader.scanSource(selected);
    renderMedia();
    setStatus(state.media.length ? "Review the queue, then choose a download folder." : "No eligible media was found in that folder.");
  } catch (error) { setStatus(error.message, true); }
  updateDownloadButton();
});

byId("destination-button").addEventListener("click", async () => {
  const selected = await window.offloader.chooseFolder("Choose a download folder");
  if (!selected) return;
  state.destinationPath = selected;
  byId("destination-path").textContent = selected;
  setStatus("Ready to review and download.");
  updateDownloadButton();
});

byId("download-button").addEventListener("click", async () => {
  try {
    const plan = await window.offloader.planCopy(state.sourcePath, state.destinationPath, state.media);
    byId("download-button").disabled = true;
    setStatus("Copying and verifying files...");
    const result = await window.offloader.executeCopy(plan);
    const conflictSuffix = result.conflicts.length ? ` ${result.conflicts.length} conflict${result.conflicts.length === 1 ? " was" : "s were"} left untouched.` : "";
    setStatus(`Verified ${result.copied} copied file${result.copied === 1 ? "" : "s"}; skipped ${result.skipped} identical file${result.skipped === 1 ? "" : "s"}.${conflictSuffix}`, Boolean(result.conflicts.length));
  } catch (error) { setStatus(error.message, true); }
  updateDownloadButton();
});

window.offloader.onCopyProgress((progress) => setStatus(`${progress.status}: ${progress.item.filename} (${progress.index}/${progress.total})`));
