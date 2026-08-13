function configureUpdatePrompts({ updater, dialog, log = () => {} }) {
  updater.autoDownload = false;
  updater.autoInstallOnAppQuit = false;

  updater.on("update-available", async (update) => {
    const result = await dialog.showMessageBox({
      type: "info",
      title: "Update available",
      message: `Dashcam Offloader ${update.version} is available.`,
      detail: "Download the update now? It will not change this app until you approve the restart.",
      buttons: ["Download update", "Not now"],
      defaultId: 0,
      cancelId: 1
    });
    if (result.response === 0) await updater.downloadUpdate();
  });

  updater.on("update-downloaded", async (update) => {
    const result = await dialog.showMessageBox({
      type: "info",
      title: "Update ready",
      message: `Dashcam Offloader ${update.version} is ready to install.`,
      detail: "Restart now to finish the update?",
      buttons: ["Restart now", "Later"],
      defaultId: 0,
      cancelId: 1
    });
    if (result.response === 0) updater.quitAndInstall();
  });

  updater.on("error", (error) => log(`Update check failed: ${error.message}`));
}

async function checkForUpdates({ updater, log = () => {} }) {
  try {
    return await updater.checkForUpdates();
  } catch (error) {
    log(`Update check failed: ${error.message}`);
    return null;
  }
}

module.exports = { checkForUpdates, configureUpdatePrompts };
