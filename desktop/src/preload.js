const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("offloader", {
  chooseSourceFolder: () => ipcRenderer.invoke("choose-folder", "source"),
  chooseDestinationFolder: () => ipcRenderer.invoke("choose-folder", "destination"),
  scanSource: (sourceToken) => ipcRenderer.invoke("scan-source", sourceToken),
  planCopy: (sourceToken, destinationToken) => ipcRenderer.invoke("copy-plan", sourceToken, destinationToken),
  executeCopy: (token) => ipcRenderer.invoke("execute-copy", token),
  checkForUpdates: () => ipcRenderer.invoke("check-for-updates"),
  onCopyProgress: (handler) => ipcRenderer.on("copy-progress", (_event, progress) => handler(progress))
});
