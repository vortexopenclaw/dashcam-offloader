const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");

const MEDIA_EXTENSIONS = new Set([".3gp", ".avi", ".jpeg", ".jpg", ".m4v", ".mkv", ".mov", ".mp4", ".png", ".webm"]);
const EXCLUDED_DIRECTORIES = new Set([".spotlight-v100", ".trashes", "system volume information"]);

function isPathWithin(childPath, parentPath) {
  const relative = path.relative(path.resolve(parentPath), path.resolve(childPath));
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== "..");
}

function safeFilename(sourcePath) {
  const filename = path.basename(sourcePath).replace(/[<>:"/\\|?*\u0000-\u001f]/g, "_").trim();
  if (!filename || filename === "." || filename === "..") throw new Error("A source filename cannot be used safely.");
  return filename;
}

function safeRelativePath(relativePath) {
  const components = relativePath.split(path.sep);
  if (!components.length || components.some((component) => component === "" || component === "." || component === "..")) {
    throw new Error("A source path cannot be used safely.");
  }
  return path.join(...components.map(safeFilename));
}

async function sha256(filePath) {
  const contents = await fs.readFile(filePath);
  return crypto.createHash("sha256").update(contents).digest("hex");
}

async function scanSource(sourcePath) {
  const root = path.resolve(sourcePath);
  const rootStat = await fs.stat(root);
  if (!rootStat.isDirectory()) throw new Error("The selected source must be a folder.");

  const media = [];
  async function visit(directoryPath) {
    const entries = await fs.readdir(directoryPath, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith(".")) continue;
      const entryPath = path.join(directoryPath, entry.name);
      if (entry.isDirectory()) {
        if (!EXCLUDED_DIRECTORIES.has(entry.name.toLowerCase())) await visit(entryPath);
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
  await visit(root);
  return media.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
}

function planCopy(sourcePath, destinationPath, media) {
  const source = path.resolve(sourcePath);
  const destination = path.resolve(destinationPath);
  if (isPathWithin(destination, source)) throw new Error("Choose a download folder outside the source card or folder.");
  return media.map((item) => ({ ...item, destinationPath: path.join(destination, safeRelativePath(item.relativePath)) }));
}

async function executeCopy(plan, onProgress = () => {}) {
  let copied = 0;
  let skipped = 0;
  const conflicts = [];
  for (let index = 0; index < plan.length; index += 1) {
    const item = plan[index];
    await fs.mkdir(path.dirname(item.destinationPath), { recursive: true });
    try {
      const destinationStat = await fs.stat(item.destinationPath);
      if (destinationStat.size === item.bytes && await sha256(item.sourcePath) === await sha256(item.destinationPath)) {
        skipped += 1;
        onProgress({ index: index + 1, total: plan.length, item, status: "Skipped" });
        continue;
      }
      conflicts.push({ ...item, reason: "An existing destination file differs and was left untouched." });
      onProgress({ index: index + 1, total: plan.length, item, status: "Conflict" });
      continue;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }

    try {
      await fs.copyFile(item.sourcePath, item.destinationPath, fs.constants.COPYFILE_EXCL);
      const destinationStat = await fs.stat(item.destinationPath);
      if (destinationStat.size !== item.bytes || await sha256(item.sourcePath) !== await sha256(item.destinationPath)) {
        await fs.unlink(item.destinationPath);
        throw new Error("Copied file did not verify and was removed.");
      }
      copied += 1;
      onProgress({ index: index + 1, total: plan.length, item, status: "Copied" });
    } catch (error) {
      if (error.code === "EEXIST") {
        conflicts.push({ ...item, reason: "A destination file appeared during copy and was left untouched." });
        continue;
      }
      throw error;
    }
  }
  return { copied, skipped, conflicts };
}

module.exports = { executeCopy, isPathWithin, planCopy, scanSource, sha256 };
