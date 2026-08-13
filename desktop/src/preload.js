const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("offloader", {
  chooseFolder: (title) => ipcRenderer.invoke("choose-folder", title),
  scanSource: (sourcePath) => ipcRenderer.invoke("scan-source", sourcePath),
  planCopy: (sourcePath, destinationPath, media) => ipcRenderer.invoke("copy-plan", sourcePath, destinationPath, media),
  executeCopy: (plan) => ipcRenderer.invoke("execute-copy", plan),
  checkForUpdates: () => ipcRenderer.invoke("check-for-updates"),
  onCopyProgress: (handler) => ipcRenderer.on("copy-progress", (_event, progress) => handler(progress))
});
