const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const { autoUpdater } = require("electron-updater");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const packageMetadata = require("../package.json");
const { createAccessController, publicCopyResult } = require("./access-controller");
const { assertTrustedSender } = require("./ipc-security");
const { executeCopy, planCopy, scanSource } = require("./offload-engine");
const { checkForUpdates, configureUpdatePrompts } = require("./update-controller");

const access = createAccessController();
const updatesEnabled = app.isPackaged && packageMetadata.updateEnabled === true;
const rendererPath = path.join(__dirname, "renderer", "index.html");
const rendererURL = pathToFileURL(rendererPath).href;

function createWindow() {
  const window = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 860,
    minHeight: 620,
    webPreferences: {
      allowRunningInsecureContent: false,
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, "preload.js"),
      sandbox: true,
      webSecurity: true
    }
  });
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  window.webContents.on("will-navigate", (event) => event.preventDefault());
  window.loadFile(rendererPath);
}

app.whenReady().then(() => {
  app.on("web-contents-created", (_event, contents) => {
    contents.session.setPermissionCheckHandler(() => false);
    contents.session.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false));
  });
  ipcMain.handle("choose-folder", async (event, kind) => {
    assertTrustedSender(event, rendererURL);
    if (!new Set(["source", "destination"]).has(kind)) throw new Error("Invalid folder type.");
    const title = kind === "source" ? "Choose a memory card or video folder" : "Choose a download folder";
    const result = await dialog.showOpenDialog({ title, properties: ["openDirectory"] });
    return result.canceled ? null : access.approveFolder(kind, result.filePaths[0]);
  });
  ipcMain.handle("scan-source", (event, sourceToken) => {
    assertTrustedSender(event, rendererURL);
    return access.scanApprovedSource(sourceToken, scanSource);
  });
  ipcMain.handle("copy-plan", (event, sourceToken, destinationToken) => {
    assertTrustedSender(event, rendererURL);
    return access.createCopyPlan(sourceToken, destinationToken, planCopy);
  });
  ipcMain.handle("execute-copy", async (event, token) => {
    assertTrustedSender(event, rendererURL);
    const result = await executeCopy(access.consumeCopyPlan(token), (progress) => {
      event.sender.send("copy-progress", {
        index: progress.index,
        total: progress.total,
        status: progress.status,
        filename: progress.item.filename
      });
    });
    return publicCopyResult(result);
  });
  ipcMain.handle("check-for-updates", (event) => {
    assertTrustedSender(event, rendererURL);
    return updatesEnabled
      ? checkForUpdates({ updater: autoUpdater, log: console.info })
      : { supported: false };
  });
  createWindow();
  if (updatesEnabled) {
    configureUpdatePrompts({ updater: autoUpdater, dialog, log: console.info });
    void checkForUpdates({ updater: autoUpdater, log: console.info });
  }
  app.on("activate", () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
