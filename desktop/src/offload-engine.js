const crypto = require("node:crypto");
const fsSync = require("node:fs");
const fs = require("node:fs/promises");
const path = require("node:path");

const MEDIA_EXTENSIONS = new Set([".3gp", ".avi", ".jpeg", ".jpg", ".m4v", ".mkv", ".mov", ".mp4", ".png", ".webm"]);
const EXCLUDED_DIRECTORIES = new Set([".spotlight-v100", ".trashes", "system volume information"]);

// pathModule is injectable so Windows drive semantics are testable on any host.
function isPathWithin(childPath, parentPath, pathModule = path) {
  const relative = pathModule.relative(pathModule.resolve(parentPath), pathModule.resolve(childPath));
  // path.relative returns an absolute path when the two are on different Windows drives.
  return relative === "" ||
    (!relative.startsWith(`..${pathModule.sep}`) && relative !== ".." && !pathModule.isAbsolute(relative));
}

// Windows treats these stems as devices in any folder ("CON.mp4" opens the console).
const WINDOWS_RESERVED = /^(con|prn|aux|nul|com[1-9\u00b9\u00b2\u00b3]|lpt[1-9\u00b9\u00b2\u00b3])$/i;

function safeFilename(sourcePath) {
  // Windows also silently drops trailing dots and spaces, which can merge two names.
  let filename = path.basename(sourcePath).replace(/[<>:"/\\|?*\u0000-\u001f]/g, "_").trim().replace(/[. ]+$/, "");
  if (!filename || filename === "." || filename === "..") throw new Error("A source filename cannot be used safely.");
  if (WINDOWS_RESERVED.test(filename.split(".")[0].trim())) filename = `_${filename}`;
  return filename;
}

function safeRelativePath(relativePath) {
  // Windows accepts both separators, so "../x" must count as traversal there too.
  const components = relativePath.split(path.sep === "\\" ? /[\\/]/ : path.sep);
  if (!components.length || components.some((component) => component === "" || component === "." || component === "..")) {
    throw new Error("A source path cannot be used safely.");
  }
  return path.join(...components.map(safeFilename));
}

async function sha256(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fsSync.createReadStream(filePath);
    stream.on("error", reject);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

class UnsafeCopyItemError extends Error {}

// O_NOFOLLOW refuses a final-component symlink; O_NONBLOCK keeps a named pipe or
// device from blocking the open. Both are 0 where the platform lacks them.
const SOURCE_OPEN_FLAGS = fsSync.constants.O_RDONLY |
  (fsSync.constants.O_NOFOLLOW || 0) | (fsSync.constants.O_NONBLOCK || 0);

// The scan result is only a snapshot. Re-check, at copy time, that the reviewed
// path is still a regular file inside the approved source, and keep the open
// descriptor so the bytes copied are the bytes checked.
async function openVerifiedSource(item) {
  let handle;
  try {
    const linkStat = await fs.lstat(item.sourcePath);
    if (!linkStat.isFile()) throw new UnsafeCopyItemError("The source is no longer a regular file and was not copied.");
    handle = await fs.open(item.sourcePath, SOURCE_OPEN_FLAGS);
    const stat = await handle.stat();
    if (!stat.isFile()) throw new UnsafeCopyItemError("The source is no longer a regular file and was not copied.");
    if (item.sourceRoot) {
      const [realSource, realRoot] = await Promise.all([fs.realpath(item.sourcePath), fs.realpath(item.sourceRoot)]);
      if (!isPathWithin(realSource, realRoot)) {
        throw new UnsafeCopyItemError("The source now resolves outside the approved source folder and was not copied.");
      }
      // Compare identity so a swap between the open and the path check cannot pass.
      const realStat = await fs.stat(realSource);
      if (realStat.dev !== stat.dev || realStat.ino !== stat.ino) {
        throw new UnsafeCopyItemError("The source changed during the copy and was not copied.");
      }
    }
    return handle;
  } catch (error) {
    await handle?.close().catch(() => {});
    if (error instanceof UnsafeCopyItemError) throw error;
    if (["ENOENT", "ENOTDIR", "ELOOP", "EMLINK", "ENXIO"].includes(error.code)) {
      throw new UnsafeCopyItemError("The source changed since the scan and was not copied.");
    }
    throw error;
  }
}

// Create the destination folder, then confirm that symbolic links already in the
// destination did not redirect it outside the chosen folder or back onto the source.
async function prepareDestinationDirectory(item) {
  const directory = path.dirname(item.destinationPath);
  await fs.mkdir(directory, { recursive: true });
  if (!item.destinationRoot) return;
  const [realDirectory, realRoot] = await Promise.all([fs.realpath(directory), fs.realpath(item.destinationRoot)]);
  if (!isPathWithin(realDirectory, realRoot)) {
    throw new UnsafeCopyItemError("The destination folder resolves outside the chosen download folder; nothing was written.");
  }
  if (item.sourceRoot) {
    let realSourceRoot = null;
    try { realSourceRoot = await fs.realpath(item.sourceRoot); } catch { /* source vanished; handled when it is opened */ }
    if (realSourceRoot && isPathWithin(realDirectory, realSourceRoot)) {
      throw new UnsafeCopyItemError("The destination folder resolves inside the source; nothing was written.");
    }
  }
}

function hashStream(stream) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    stream.on("error", reject);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

// Copy from the verified descriptor into a file this call created exclusively.
// Returns the SHA-256 of the bytes that were read from the source.
async function copyFromHandle(sourceHandle, destinationPath) {
  const destinationHandle = await fs.open(destinationPath, "wx");
  try {
    const hash = crypto.createHash("sha256");
    const buffer = Buffer.allocUnsafe(1024 * 1024);
    let position = 0;
    while (true) {
      const { bytesRead } = await sourceHandle.read(buffer, 0, buffer.length, position);
      if (bytesRead === 0) break;
      const chunk = buffer.subarray(0, bytesRead);
      hash.update(chunk);
      await destinationHandle.writeFile(chunk);
      position += bytesRead;
    }
    await destinationHandle.sync();
    return hash.digest("hex");
  } catch (error) {
    await destinationHandle.close().catch(() => {});
    await fs.unlink(destinationPath).catch(() => {});
    throw error;
  } finally {
    await destinationHandle.close().catch(() => {});
  }
}

async function scanSource(sourcePath) {
  const root = path.resolve(sourcePath);
  const rootStat = await fs.stat(root);
  if (!rootStat.isDirectory()) throw new Error("The selected source must be a folder.");

  const media = [];
  const pendingDirectories = [root];
  let visitedEntries = 0;
  while (pendingDirectories.length > 0) {
    const directoryPath = pendingDirectories.pop();
    const entries = await fs.readdir(directoryPath, { withFileTypes: true });
    for (const entry of entries) {
      visitedEntries += 1;
      if (visitedEntries > 500000) throw new Error("The selected source contains too many entries to scan safely.");
      if (entry.name.startsWith(".")) continue;
      const entryPath = path.join(directoryPath, entry.name);
      if (entry.isDirectory()) {
        if (!EXCLUDED_DIRECTORIES.has(entry.name.toLowerCase())) pendingDirectories.push(entryPath);
        continue;
      }
      if (!entry.isFile() || !MEDIA_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) continue;
      const stat = await fs.stat(entryPath);
      media.push({
        sourcePath: entryPath,
        relativePath: path.relative(root, entryPath),
        filename: safeFilename(entryPath),
        bytes: stat.size,
        kind: [".jpeg", ".jpg", ".png"].includes(path.extname(entry.name).toLowerCase()) ? "Photo" : "Video"
      });
    }
  }
  return media.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
}

function planCopy(sourcePath, destinationPath, media) {
  const source = path.resolve(sourcePath);
  const destination = path.resolve(destinationPath);
  if (isPathWithin(destination, source)) throw new Error("Choose a download folder outside the source card or folder.");
  return media.map((item) => {
    if (!isPathWithin(item.sourcePath, source)) throw new Error("A planned source file is outside the approved source folder.");
    const destinationPath = path.join(destination, safeRelativePath(item.relativePath));
    if (!isPathWithin(destinationPath, destination) || destinationPath === destination) {
      throw new Error("A planned destination is outside the download folder.");
    }
    return { ...item, sourceRoot: source, destinationRoot: destination, destinationPath };
  });
}

async function executeCopy(plan, onProgress = () => {}) {
  let copied = 0;
  let skipped = 0;
  const conflicts = [];
  for (let index = 0; index < plan.length; index += 1) {
    const item = plan[index];
    let sourceHandle;
    try {
      await prepareDestinationDirectory(item);
      sourceHandle = await openVerifiedSource(item);

      let destinationExists = true;
      try {
        // lstat: a symbolic link at the destination is a conflict, never a write target.
        const destinationStat = await fs.lstat(item.destinationPath);
        if (destinationStat.isFile() && destinationStat.size === item.bytes &&
            await hashStream(sourceHandle.createReadStream({ autoClose: false, start: 0 })) === await sha256(item.destinationPath)) {
          skipped += 1;
          onProgress({ index: index + 1, total: plan.length, item, status: "Skipped" });
          continue;
        }
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
        destinationExists = false;
      }
      if (destinationExists) {
        conflicts.push({ ...item, reason: "An existing destination file differs and was left untouched." });
        onProgress({ index: index + 1, total: plan.length, item, status: "Conflict" });
        continue;
      }

      const sourceDigest = await copyFromHandle(sourceHandle, item.destinationPath);
      const destinationStat = await fs.stat(item.destinationPath);
      if (destinationStat.size !== item.bytes || sourceDigest !== await sha256(item.destinationPath)) {
        await fs.unlink(item.destinationPath);
        throw new Error("Copied file did not verify and was removed.");
      }
      copied += 1;
      onProgress({ index: index + 1, total: plan.length, item, status: "Copied" });
    } catch (error) {
      if (error.code === "EEXIST") {
        conflicts.push({ ...item, reason: "A destination file appeared during copy and was left untouched." });
        onProgress({ index: index + 1, total: plan.length, item, status: "Conflict" });
        continue;
      }
      if (error instanceof UnsafeCopyItemError) {
        conflicts.push({ ...item, reason: error.message });
        onProgress({ index: index + 1, total: plan.length, item, status: "Not copied" });
        continue;
      }
      throw error;
    } finally {
      await sourceHandle?.close().catch(() => {});
    }
  }
  return { copied, skipped, conflicts };
}

module.exports = { executeCopy, isPathWithin, planCopy, safeFilename, scanSource, sha256 };
