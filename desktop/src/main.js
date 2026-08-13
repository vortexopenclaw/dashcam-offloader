const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const { autoUpdater } = require("electron-updater");
const path = require("node:path");
const { executeCopy, planCopy, scanSource } = require("./offload-engine");
const { checkForUpdates, configureUpdatePrompts } = require("./update-controller");

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
  ipcMain.handle("check-for-updates", () => checkForUpdates({ updater: autoUpdater, log: console.info }));
  createWindow();
  if (app.isPackaged) {
    configureUpdatePrompts({ updater: autoUpdater, dialog, log: console.info });
    void checkForUpdates({ updater: autoUpdater, log: console.info });
  }
  app.on("activate", () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
