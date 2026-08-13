const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const path = require("node:path");
const { executeCopy, planCopy, scanSource } = require("./offload-engine");

function createWindow() {
  const window = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 860,
    minHeight: 620,
    webPreferences: { contextIsolation: true, preload: path.join(__dirname, "preload.js") }
  });
  window.loadFile(path.join(__dirname, "renderer", "index.html"));
}

app.whenReady().then(() => {
  ipcMain.handle("choose-folder", async (_event, title) => {
    const result = await dialog.showOpenDialog({ title, properties: ["openDirectory"] });
    return result.canceled ? null : result.filePaths[0];
  });
  ipcMain.handle("scan-source", (_event, sourcePath) => scanSource(sourcePath));
  ipcMain.handle("copy-plan", (_event, sourcePath, destinationPath, media) => planCopy(sourcePath, destinationPath, media));
  ipcMain.handle("execute-copy", async (event, plan) => executeCopy(plan, (progress) => event.sender.send("copy-progress", progress)));
  createWindow();
  app.on("activate", () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
