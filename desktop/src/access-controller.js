const crypto = require("node:crypto");
const fs = require("node:fs/promises");

function createAccessController({ realpath = fs.realpath, randomUUID = crypto.randomUUID } = {}) {
  const folders = new Map();
  const scans = new Map();
  const plans = new Map();

  async function approveFolder(kind, folderPath) {
    if (!new Set(["source", "destination"]).has(kind)) throw new Error("Invalid folder approval type.");
    const canonicalPath = await realpath(folderPath);
    const token = randomUUID();
    folders.set(token, { kind, path: canonicalPath });
    return { token, displayName: require("node:path").basename(canonicalPath) || canonicalPath };
  }

  function resolveFolder(kind, token) {
    const folder = typeof token === "string" ? folders.get(token) : null;
    if (!folder || folder.kind !== kind) throw new Error(`The ${kind} folder must be chosen in the app first.`);
    return folder.path;
  }

  async function scanApprovedSource(sourceToken, scanner) {
    const sourcePath = resolveFolder("source", sourceToken);
    const media = await scanner(sourcePath);
    scans.set(sourceToken, media);
    return media.map(({ relativePath, filename, bytes, kind }) => ({ relativePath, filename, bytes, kind }));
  }

  function createCopyPlan(sourceToken, destinationToken, planner) {
    const sourcePath = resolveFolder("source", sourceToken);
    const destinationPath = resolveFolder("destination", destinationToken);
    const media = scans.get(sourceToken);
    if (!media) throw new Error("Scan the selected source before creating a copy plan.");
    const plan = planner(sourcePath, destinationPath, media);
    const token = randomUUID();
    plans.set(token, plan);
    return { token, totalFiles: plan.length };
  }

  function consumeCopyPlan(token) {
    if (typeof token !== "string" || !plans.has(token)) throw new Error("The copy plan is unavailable or expired.");
    const plan = plans.get(token);
    plans.delete(token);
    return plan;
  }

  return { approveFolder, consumeCopyPlan, createCopyPlan, scanApprovedSource };
}

function publicCopyResult(result) {
  return {
    copied: result.copied,
    skipped: result.skipped,
    conflicts: result.conflicts.map(({ filename, reason }) => ({ filename, reason }))
  };
}

module.exports = { createAccessController, publicCopyResult };
