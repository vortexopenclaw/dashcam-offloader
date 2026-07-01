const MAX_MESSAGE_LENGTH = 12000;
const MAX_CONTACT_LENGTH = 240;
const MAX_SAMPLE_PATHS = 80;
const MAX_FILENAME_PATTERN_SUMMARIES = 160;
const MAX_FILENAME_SEQUENCE_SUMMARIES = 240;
const MAX_DIRECTORY_SUMMARIES = 160;
const MAX_CLIP_GROUP_SUMMARIES = 160;
const MAX_VIDEO_SPEC_SAMPLES = 64;
const MAX_VIDEO_SPEC_SUMMARIES = 120;
const MAX_SETTING_SNAPSHOTS = 20;
const MAX_SETTING_VALUES = 40;
const MAX_TRAINING_FIELD_LENGTH = 1000;
const MAX_BODY_BYTES = 1024 * 1024;
const RATE_LIMIT_WINDOW_SECONDS = 60 * 60;
const RATE_LIMIT_MAX_POSTS = 20;
const SECURITY_TXT = `Contact: mailto:security@vortexradar.com
Contact: https://www.vortexradar.com/security-contact/
Preferred-Languages: en
Canonical: https://www.vortexradar.com/.well-known/security.txt
Policy: https://www.vortexradar.com/security-contact/
Expires: 2027-06-17T23:59:59Z
`;

function securityTxtResponse(method) {
  return new Response(method === "HEAD" ? null : SECURITY_TXT, {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "public, max-age=86400",
      "access-control-allow-origin": "*",
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/.well-known/security.txt" && ["GET", "HEAD"].includes(request.method)) {
      return securityTxtResponse(request.method);
    }

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: responseHeaders(request, env) });
    }

    if (url.pathname !== "/feedback") {
      return json({ error: "not_found" }, 404, request, env);
    }

    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405, request, env);
    }

    const rateLimit = await checkRateLimit(request, env);
    if (!rateLimit.ok) {
      return json(
        { error: "rate_limited" },
        429,
        request,
        env,
        { "Retry-After": String(rateLimit.retryAfterSeconds) }
      );
    }

    const contentLength = Number(request.headers.get("Content-Length") || "0");
    if (contentLength > MAX_BODY_BYTES) {
      return json({ error: "payload_too_large" }, 413, request, env);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400, request, env);
    }

    if (JSON.stringify(body).length > MAX_BODY_BYTES) {
      return json({ error: "payload_too_large" }, 413, request, env);
    }

    const validation = validateFeedback(body);
    if (!validation.ok) {
      return json({ error: validation.error }, 400, request, env);
    }

    const receivedAt = new Date().toISOString();
    const id = crypto.randomUUID();
    const record = {
      id,
      receivedAt,
      source: "dashcam-offloader-mac",
      ...sanitizeFeedback(body),
    };

    if (!hasStorageBinding(env)) {
      return json({ error: "storage_not_configured" }, 503, request, env);
    }

    await storeRecord(env, id, record);

    return json({ ok: true, id }, 202, request, env);
  },
};

async function checkRateLimit(request, env) {
  if (!env.FEEDBACK_KV) {
    return { ok: true };
  }

  const now = Date.now();
  const windowStart = Math.floor(now / (RATE_LIMIT_WINDOW_SECONDS * 1000));
  const clientID = await hashedClientID(request, env);
  const key = `rate/${windowStart}/${clientID}`;
  const current = Number(await env.FEEDBACK_KV.get(key) || "0");

  if (current >= RATE_LIMIT_MAX_POSTS) {
    const nextWindowAt = (windowStart + 1) * RATE_LIMIT_WINDOW_SECONDS * 1000;
    return {
      ok: false,
      retryAfterSeconds: Math.max(1, Math.ceil((nextWindowAt - now) / 1000)),
    };
  }

  await env.FEEDBACK_KV.put(key, String(current + 1), {
    expirationTtl: RATE_LIMIT_WINDOW_SECONDS * 2,
  });

  return { ok: true };
}

async function hashedClientID(request, env) {
  const rawClient = request.headers.get("CF-Connecting-IP") || "unknown";
  return clientFingerprint(rawClient, String(env.RATE_LIMIT_SALT || ""));
}

async function clientFingerprint(rawClient, salt) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${salt}:${rawClient}`)
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function validateFeedback(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, error: "body_must_be_object" };
  }

  if (!["bug", "feature", "training", "other"].includes(body.kind)) {
    return { ok: false, error: "invalid_kind" };
  }

  if (typeof body.message !== "string" || body.message.trim().length === 0) {
    return { ok: false, error: "message_required" };
  }

  if (body.message.length > MAX_MESSAGE_LENGTH) {
    return { ok: false, error: "message_too_long" };
  }

  if (body.contact && (typeof body.contact !== "string" || body.contact.length > MAX_CONTACT_LENGTH)) {
    return { ok: false, error: "invalid_contact" };
  }

  if (body.kind === "training") {
    if (!body.training || typeof body.training !== "object" || Array.isArray(body.training)) {
      return { ok: false, error: "training_required" };
    }
    for (const field of ["manufacturer", "model", "channelSetup"]) {
      if (typeof body.training[field] !== "string" || body.training[field].trim().length === 0) {
        return { ok: false, error: `training_${field}_required` };
      }
      if (body.training[field].length > MAX_TRAINING_FIELD_LENGTH) {
        return { ok: false, error: `training_${field}_too_long` };
      }
    }
  }

  if (body.scan !== null && body.scan !== undefined) {
    const scan = body.scan;
    if (typeof scan !== "object" || Array.isArray(scan)) {
      return { ok: false, error: "invalid_scan" };
    }
    if (Array.isArray(scan.sampleRelativePaths) && scan.sampleRelativePaths.length > MAX_SAMPLE_PATHS) {
      return { ok: false, error: "too_many_sample_paths" };
    }
    if (Array.isArray(scan.settingSnapshots) && scan.settingSnapshots.length > MAX_SETTING_SNAPSHOTS) {
      return { ok: false, error: "too_many_setting_snapshots" };
    }
  }

  return { ok: true };
}

function sanitizeFeedback(body) {
  const scan = body.scan ? sanitizeScan(body.scan) : null;

  return {
    kind: body.kind,
    message: body.message.trim(),
    contact: String(body.contact || "").trim(),
    appVersion: String(body.appVersion || ""),
    createdAt: String(body.createdAt || ""),
    training: body.training ? sanitizeTraining(body.training) : null,
    scan,
  };
}

function sanitizeTraining(training) {
  return {
    manufacturer: stringValue(training.manufacturer).trim(),
    model: stringValue(training.model).trim(),
    channelSetup: stringValue(training.channelSetup).trim(),
    notes: stringValue(training.notes).trim(),
  };
}

function sanitizeScan(scan) {
  return {
    volumeName: stringValue(scan.volumeName),
    requestedSourceName: optionalString(scan.requestedSourceName),
    effectiveSourceName: optionalString(scan.effectiveSourceName),
    effectiveSourceRelativePath: optionalString(scan.effectiveSourceRelativePath),
    identifiedCamera: sanitizeIdentifiedCamera(scan.identifiedCamera),
    selectedProfileID: optionalString(scan.selectedProfileID),
    selectedProfileName: optionalString(scan.selectedProfileName),
    scannedFiles: numberValue(scan.scannedFiles),
    copyableItems: numberValue(scan.copyableItems),
    excludedItems: numberValue(scan.excludedItems),
    categoryCounts: countMap(scan.categoryCounts),
    modeCounts: countMap(scan.modeCounts),
    displayModeCounts: countMap(scan.displayModeCounts),
    outputCategoryCounts: countMap(scan.outputCategoryCounts),
    channelCounts: countMap(scan.channelCounts),
    extensionCounts: countMap(scan.extensionCounts),
    mediaExtensionCounts: countMap(scan.mediaExtensionCounts),
    unrecognizedExtensionCounts: countMap(scan.unrecognizedExtensionCounts),
    timestampSourceCounts: countMap(scan.timestampSourceCounts),
    suspiciousTimestampItems: numberValue(scan.suspiciousTimestampItems),
    inferredParkingPatternCounts: countMap(scan.inferredParkingPatternCounts),
    sampleRelativePaths: safePathList(scan.sampleRelativePaths, MAX_SAMPLE_PATHS),
    rootFolders: safePathList(scan.rootFolders, 40),
    folderSamples: safePathList(scan.folderSamples, MAX_SAMPLE_PATHS),
    directorySummaries: Array.isArray(scan.directorySummaries)
      ? scan.directorySummaries.slice(0, MAX_DIRECTORY_SUMMARIES).map(sanitizeDirectorySummary).filter(Boolean)
      : [],
    folderSummaries: Array.isArray(scan.folderSummaries)
      ? scan.folderSummaries.slice(0, 80).map(sanitizeFolderSummary).filter(Boolean)
      : [],
    filenameSamples: safePathList(scan.filenameSamples, MAX_SAMPLE_PATHS),
    filenamePatternSummaries: Array.isArray(scan.filenamePatternSummaries)
      ? scan.filenamePatternSummaries.slice(0, MAX_FILENAME_PATTERN_SUMMARIES).map(sanitizeFilenamePatternSummary).filter(Boolean)
      : [],
    filenameSequenceSummaries: Array.isArray(scan.filenameSequenceSummaries)
      ? scan.filenameSequenceSummaries.slice(0, MAX_FILENAME_SEQUENCE_SUMMARIES).map(sanitizeFilenameSequenceSummary).filter(Boolean)
      : [],
    supportFileSamples: safePathList(scan.supportFileSamples, 40),
    ignoredSupportFileSamples: safePathList(scan.ignoredSupportFileSamples, 60),
    clipGroupSummaries: Array.isArray(scan.clipGroupSummaries)
      ? scan.clipGroupSummaries.slice(0, MAX_CLIP_GROUP_SUMMARIES).map(sanitizeClipGroupSummary).filter(Boolean)
      : [],
    videoSpecSamples: Array.isArray(scan.videoSpecSamples)
      ? scan.videoSpecSamples.slice(0, MAX_VIDEO_SPEC_SAMPLES).map(sanitizeVideoSpecSample).filter(Boolean)
      : [],
    videoSpecSummaries: Array.isArray(scan.videoSpecSummaries)
      ? scan.videoSpecSummaries.slice(0, MAX_VIDEO_SPEC_SUMMARIES).map(sanitizeVideoSpecSummary).filter(Boolean)
      : [],
    settingSnapshots: Array.isArray(scan.settingSnapshots)
      ? scan.settingSnapshots.slice(0, MAX_SETTING_SNAPSHOTS).map(sanitizeSettingSnapshot).filter(Boolean)
      : [],
    candidates: Array.isArray(scan.candidates)
      ? scan.candidates.slice(0, 12).map(sanitizeCandidate)
      : [],
    scanDiagnostics: Array.isArray(scan.scanDiagnostics)
      ? scan.scanDiagnostics.slice(0, 40).map(sanitizeScanDiagnostic)
      : [],
  };
}

function sanitizeDirectorySummary(summary) {
  if (!summary || typeof summary !== "object" || Array.isArray(summary)) {
    return null;
  }

  const path = sanitizePath(summary.path || ".");
  if (!path) {
    return null;
  }

  return {
    path,
    depth: numberValue(summary.depth),
    childDirectoryCount: numberValue(summary.childDirectoryCount),
    directFileCount: numberValue(summary.directFileCount),
    directMediaFileCount: numberValue(summary.directMediaFileCount),
    directSupportFileCount: numberValue(summary.directSupportFileCount),
    directHiddenFileCount: numberValue(summary.directHiddenFileCount),
    directPlaceholderFileCount: numberValue(summary.directPlaceholderFileCount),
    directTotalFileSizeBytes: numberValue(summary.directTotalFileSizeBytes),
    extensionCounts: countMap(summary.extensionCounts),
    sampleFilenames: safePathList(summary.sampleFilenames, 8),
  };
}

function sanitizeIdentifiedCamera(camera) {
  if (!camera || typeof camera !== "object" || Array.isArray(camera)) {
    return null;
  }

  const manufacturer = stringValue(camera.manufacturer).trim();
  const model = stringValue(camera.model).trim();
  if (!manufacturer || !model) {
    return null;
  }

  return {
    manufacturer,
    model,
    evidence: stringList(camera.evidence, 12),
    isSupported: Boolean(camera.isSupported),
  };
}

function sanitizeFolderSummary(summary) {
  if (!summary || typeof summary !== "object" || Array.isArray(summary)) {
    return null;
  }

  const path = sanitizePath(summary.path);
  if (!path) {
    return null;
  }

  return {
    path,
    fileCount: numberValue(summary.fileCount),
    mediaFileCount: numberValue(summary.mediaFileCount),
    supportFileCount: numberValue(summary.supportFileCount),
    totalFileSizeBytes: numberValue(summary.totalFileSizeBytes),
    minFileSizeBytes: nullableNumber(summary.minFileSizeBytes),
    maxFileSizeBytes: nullableNumber(summary.maxFileSizeBytes),
    extensionCounts: countMap(summary.extensionCounts),
  };
}

function sanitizeFilenamePatternSummary(summary) {
  if (!summary || typeof summary !== "object" || Array.isArray(summary)) {
    return null;
  }

  const folder = sanitizePath(summary.folder || ".");
  const redactedPattern = stringValue(summary.redactedPattern);
  if (!folder || !redactedPattern || isSensitiveSettingPair(redactedPattern, "")) {
    return null;
  }

  return {
    folder,
    extensionLowercased: stringValue(summary.extensionLowercased).toLowerCase(),
    redactedPattern,
    fileCount: numberValue(summary.fileCount),
    totalFileSizeBytes: numberValue(summary.totalFileSizeBytes),
    sampleRelativePaths: safePathList(summary.sampleRelativePaths, 8),
  };
}

function sanitizeFilenameSequenceSummary(summary) {
  if (!summary || typeof summary !== "object" || Array.isArray(summary)) {
    return null;
  }

  const folder = sanitizePath(summary.folder || ".");
  const prefix = stringValue(summary.prefix).trim();
  if (!folder || !prefix || isSensitiveSettingPair(prefix, "")) {
    return null;
  }

  return {
    folder,
    prefix,
    extensionLowercased: stringValue(summary.extensionLowercased).toLowerCase(),
    fileCount: numberValue(summary.fileCount),
    firstSequence: nullableNumber(summary.firstSequence),
    lastSequence: nullableNumber(summary.lastSequence),
    totalFileSizeBytes: numberValue(summary.totalFileSizeBytes),
    sampleRelativePaths: safePathList(summary.sampleRelativePaths, 8),
  };
}

function sanitizeClipGroupSummary(summary) {
  if (!summary || typeof summary !== "object" || Array.isArray(summary)) {
    return null;
  }

  const folder = sanitizePath(summary.folder || ".");
  if (!folder) {
    return null;
  }

  return {
    folder,
    extensionLowercased: stringValue(summary.extensionLowercased).toLowerCase(),
    mode: optionalString(summary.mode),
    displayMode: optionalString(summary.displayMode),
    outputCategory: optionalString(summary.outputCategory),
    channel: optionalString(summary.channel),
    displayChannel: optionalString(summary.displayChannel),
    inferredParkingPattern: optionalString(summary.inferredParkingPattern),
    fileCount: numberValue(summary.fileCount),
    totalFileSizeBytes: numberValue(summary.totalFileSizeBytes),
    minFileSizeBytes: nullableNumber(summary.minFileSizeBytes),
    maxFileSizeBytes: nullableNumber(summary.maxFileSizeBytes),
    firstTimestamp: optionalString(summary.firstTimestamp),
    lastTimestamp: optionalString(summary.lastTimestamp),
    timestampSourceCounts: countMap(summary.timestampSourceCounts),
    sampleRelativePaths: safePathList(summary.sampleRelativePaths, 8),
  };
}

function sanitizeVideoSpecSample(sample) {
  if (!sample || typeof sample !== "object" || Array.isArray(sample)) {
    return null;
  }

  const relativePath = sanitizePath(sample.relativePath);
  if (!relativePath) {
    return null;
  }

  return {
    relativePath,
    extensionLowercased: stringValue(sample.extensionLowercased).toLowerCase(),
    fileSizeBytes: nullableNumber(sample.fileSizeBytes),
    mode: optionalString(sample.mode),
    displayMode: optionalString(sample.displayMode),
    outputCategory: optionalString(sample.outputCategory),
    channel: optionalString(sample.channel),
    inferredParkingPattern: optionalString(sample.inferredParkingPattern),
    codec: optionalString(sample.codec),
    width: nullableNumber(sample.width),
    height: nullableNumber(sample.height),
    nominalFrameRate: nullableNumber(sample.nominalFrameRate),
    estimatedBitrate: nullableNumber(sample.estimatedBitrate),
    durationSeconds: nullableNumber(sample.durationSeconds),
  };
}

function sanitizeVideoSpecSummary(summary) {
  if (!summary || typeof summary !== "object" || Array.isArray(summary)) {
    return null;
  }

  const folder = sanitizePath(summary.folder || ".");
  if (!folder) {
    return null;
  }

  return {
    folder,
    extensionLowercased: stringValue(summary.extensionLowercased).toLowerCase(),
    mode: optionalString(summary.mode),
    displayMode: optionalString(summary.displayMode),
    outputCategory: optionalString(summary.outputCategory),
    channel: optionalString(summary.channel),
    inferredParkingPattern: optionalString(summary.inferredParkingPattern),
    fileCount: numberValue(summary.fileCount),
    totalFileSizeBytes: numberValue(summary.totalFileSizeBytes),
    minFileSizeBytes: nullableNumber(summary.minFileSizeBytes),
    maxFileSizeBytes: nullableNumber(summary.maxFileSizeBytes),
    firstTimestamp: optionalString(summary.firstTimestamp),
    lastTimestamp: optionalString(summary.lastTimestamp),
    timestampSourceCounts: countMap(summary.timestampSourceCounts),
    sampleRelativePaths: safePathList(summary.sampleRelativePaths, 10),
    sampleCodecs: stringList(summary.sampleCodecs, 6),
    sampleResolutions: stringList(summary.sampleResolutions, 6),
    sampleFrameRates: numberList(summary.sampleFrameRates, 6),
    sampleBitrateMin: nullableNumber(summary.sampleBitrateMin),
    sampleBitrateMax: nullableNumber(summary.sampleBitrateMax),
    sampleDurationMin: nullableNumber(summary.sampleDurationMin),
    sampleDurationMax: nullableNumber(summary.sampleDurationMax),
  };
}

function sanitizeSettingSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) {
    return null;
  }

  const rawValues = snapshot.safeValues && typeof snapshot.safeValues === "object" && !Array.isArray(snapshot.safeValues)
    ? snapshot.safeValues
    : {};
  const safeValues = {};

  for (const [key, value] of Object.entries(rawValues).slice(0, MAX_SETTING_VALUES)) {
    if (isSafeSettingPair(key, value)) {
      safeValues[stringValue(key)] = stringValue(value);
    }
  }

  const keys = Array.isArray(snapshot.keys)
    ? snapshot.keys
        .slice(0, MAX_SETTING_VALUES)
        .map(stringValue)
        .filter((key) => isSafeSettingPair(key, ""))
    : Object.keys(safeValues);

  if (keys.length === 0 && Object.keys(safeValues).length === 0) {
    return null;
  }

  return {
    relativePath: sanitizePath(snapshot.relativePath),
    keys,
    safeValues,
  };
}

function sanitizeCandidate(candidate) {
  return {
    profileID: stringValue(candidate.profileID),
    profileName: stringValue(candidate.profileName),
    score: numberValue(candidate.score),
    confidence: stringValue(candidate.confidence),
    evidence: Array.isArray(candidate.evidence)
      ? candidate.evidence.slice(0, 8).map(stringValue)
      : [],
  };
}

function sanitizeScanDiagnostic(diagnostic) {
  return {
    stage: stringValue(diagnostic.stage),
    profileID: optionalString(diagnostic.profileID),
    profileName: optionalString(diagnostic.profileName),
    outcome: stringValue(diagnostic.outcome),
    detail: stringValue(diagnostic.detail),
  };
}

function countMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  const result = {};
  for (const [key, count] of Object.entries(value)) {
    result[stringValue(key)] = numberValue(count);
  }
  return result;
}

function stringValue(value) {
  return typeof value === "string" ? value.slice(0, 1000) : "";
}

function sanitizePath(value) {
  return stringValue(value)
    .split("/")
    .filter((part) => !isSensitiveSettingPair(part, ""))
    .join("/")
    .slice(0, 1000);
}

function safePathList(value, limit) {
  if (!Array.isArray(value)) {
    return [];
  }
  const result = [];
  for (const item of value.slice(0, limit)) {
    const raw = stringValue(item);
    if (!raw || isSensitiveSettingPair(raw, "")) {
      continue;
    }
    const sanitized = sanitizePath(raw);
    if (sanitized) {
      result.push(sanitized);
    }
  }
  return result;
}

function stringList(value, limit) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .slice(0, limit)
    .map(stringValue)
    .filter((item) => item.length > 0);
}

function numberList(value, limit) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .slice(0, limit)
    .map(nullableNumber)
    .filter((item) => item !== null);
}

function optionalString(value) {
  return typeof value === "string" && value.length > 0 ? value.slice(0, 1000) : null;
}

function numberValue(value) {
  return Number.isFinite(value) ? value : 0;
}

function nullableNumber(value) {
  return Number.isFinite(value) ? value : null;
}

function isSafeSettingPair(key, value) {
  return !isSensitiveSettingPair(key, value) && isUsefulSettingKey(key);
}

function isUsefulSettingKey(key) {
  const normalized = stringValue(key).toLowerCase();
  const usefulFragments = [
    "model",
    "firmware",
    "version",
    "fw",
    "camera",
    "resolution",
    "quality",
    "bitrate",
    "bit rate",
    "parking",
    "motion",
    "impact",
    "timelapse",
    "time lapse",
    "low bitrate",
    "fps",
    "frame",
    "codec",
    "encoding",
    "hdr",
    "wdr",
    "loop",
    "audio",
    "microphone",
    "gps",
    "speed",
    "timezone",
    "time zone",
    "frequency",
    "exposure",
    "ev",
    "channel",
  ];
  return usefulFragments.some((fragment) => normalized.includes(fragment));
}

function isSensitiveSettingPair(key, value) {
  const combined = `${stringValue(key)} ${stringValue(value)}`.toLowerCase();
  const sensitiveFragments = [
    "password",
    "passwd",
    "pwd",
    "ssid",
    "wifi",
    "wi-fi",
    "cloud",
    "account",
    "email",
    "token",
    "secret",
    "serial",
    "imei",
    "uuid",
    "uid",
    "device id",
    "deviceid",
    "mac address",
    "bluetooth",
    "latitude",
    "longitude",
    "coordinate",
    "license",
    "plate",
  ];
  return sensitiveFragments.some((fragment) => combined.includes(fragment)) ||
    /-?\d{1,3}\.\d{4,}/.test(combined);
}

async function storeRecord(env, id, record) {
  const key = `feedback/${record.receivedAt.slice(0, 10)}/${id}.json`;
  const body = JSON.stringify(record, null, 2);

  if (env.FEEDBACK_BUCKET) {
    await env.FEEDBACK_BUCKET.put(key, body, {
      httpMetadata: { contentType: "application/json" },
    });
  }

  if (env.FEEDBACK_KV) {
    await env.FEEDBACK_KV.put(key, body);
  }
}

function hasStorageBinding(env) {
  return Boolean(env.FEEDBACK_BUCKET || env.FEEDBACK_KV);
}

function json(value, status = 200, request, env, extraHeaders = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      ...responseHeaders(request, env),
      ...extraHeaders,
    },
  });
}

function responseHeaders(request, env) {
  return {
    "Access-Control-Allow-Origin": allowedOrigin(request, env),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
  };
}

function allowedOrigin(request, env) {
  const origin = request?.headers?.get("Origin") || "";
  const configured = String(env.ALLOWED_ORIGINS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (configured.length === 0) {
    return "*";
  }

  return configured.includes(origin) ? origin : configured[0];
}

export {
  validateFeedback,
  sanitizeFeedback,
  sanitizeScan,
  sanitizePath,
  safePathList,
  isSensitiveSettingPair,
  isSafeSettingPair,
  clientFingerprint,
};
