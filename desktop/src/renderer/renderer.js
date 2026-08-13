const state = { sourceToken: null, destinationToken: null, media: [] };
const byId = (id) => document.getElementById(id);
const setStatus = (text, warning = false) => { const node = byId("status"); node.textContent = text; node.className = warning ? "warning" : ""; };

function updateDownloadButton() {
  byId("download-button").disabled = !(state.sourceToken && state.destinationToken && state.media.length);
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
  const result = await window.offloader.checkForUpdates();
  setStatus(result?.supported === false
    ? "Automatic updates are disabled in this unsigned test build."
    : "Update check completed. You will be prompted if an update is available.");
});

byId("source-button").addEventListener("click", async () => {
  const selected = await window.offloader.chooseSourceFolder();
  if (!selected) return;
  state.sourceToken = selected.token;
  byId("source-path").textContent = selected.displayName;
  setStatus("Scanning source...");
  try {
    state.media = await window.offloader.scanSource(selected.token);
    renderMedia();
    setStatus(state.media.length ? "Review the queue, then choose a download folder." : "No eligible media was found in that folder.");
  } catch (error) { setStatus(error.message, true); }
  updateDownloadButton();
});

byId("destination-button").addEventListener("click", async () => {
  const selected = await window.offloader.chooseDestinationFolder();
  if (!selected) return;
  state.destinationToken = selected.token;
  byId("destination-path").textContent = selected.displayName;
  setStatus("Ready to review and download.");
  updateDownloadButton();
});

byId("download-button").addEventListener("click", async () => {
  try {
    const plan = await window.offloader.planCopy(state.sourceToken, state.destinationToken);
    byId("download-button").disabled = true;
    setStatus("Copying and verifying files...");
    const result = await window.offloader.executeCopy(plan.token);
    const conflictSuffix = result.conflicts.length ? ` ${result.conflicts.length} conflict${result.conflicts.length === 1 ? " was" : "s were"} left untouched.` : "";
    setStatus(`Verified ${result.copied} copied file${result.copied === 1 ? "" : "s"}; skipped ${result.skipped} identical file${result.skipped === 1 ? "" : "s"}.${conflictSuffix}`, Boolean(result.conflicts.length));
  } catch (error) { setStatus(error.message, true); }
  updateDownloadButton();
});

window.offloader.onCopyProgress((progress) => setStatus(`${progress.status}: ${progress.filename} (${progress.index}/${progress.total})`));
