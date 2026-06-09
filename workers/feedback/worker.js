const MAX_MESSAGE_LENGTH = 12000;
const MAX_CONTACT_LENGTH = 240;
const MAX_SAMPLE_PATHS = 80;
const MAX_SETTING_SNAPSHOTS = 20;
const MAX_SETTING_VALUES = 40;
const MAX_TRAINING_FIELD_LENGTH = 1000;
const MAX_BODY_BYTES = 256 * 1024;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: responseHeaders(request, env) });
    }

    if (url.pathname !== "/feedback") {
      return json({ error: "not_found" }, 404, request, env);
    }

    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405, request, env);
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

    await storeRecord(env, id, record);

    return json({ ok: true, id }, 202, request, env);
  },
};

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
    if (!body.scan || typeof body.scan !== "object" || Array.isArray(body.scan)) {
      return { ok: false, error: "training_needed" };
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
    identifiedCamera: sanitizeIdentifiedCamera(scan.identifiedCamera),
    selectedProfileID: optionalString(scan.selectedProfileID),
    selectedProfileName: optionalString(scan.selectedProfileName),
    scannedFiles: numberValue(scan.scannedFiles),
    copyableItems: numberValue(scan.copyableItems),
    excludedItems: numberValue(scan.excludedItems),
    categoryCounts: countMap(scan.categoryCounts),
    modeCounts: countMap(scan.modeCounts),
    extensionCounts: countMap(scan.extensionCounts),
    sampleRelativePaths: Array.isArray(scan.sampleRelativePaths)
      ? scan.sampleRelativePaths.slice(0, MAX_SAMPLE_PATHS).map(stringValue)
      : [],
    rootFolders: Array.isArray(scan.rootFolders)
      ? scan.rootFolders.slice(0, 40).map(stringValue)
      : [],
    folderSamples: Array.isArray(scan.folderSamples)
      ? scan.folderSamples.slice(0, MAX_SAMPLE_PATHS).map(stringValue)
      : [],
    filenameSamples: Array.isArray(scan.filenameSamples)
      ? scan.filenameSamples.slice(0, MAX_SAMPLE_PATHS).map(stringValue)
      : [],
    supportFileSamples: Array.isArray(scan.supportFileSamples)
      ? scan.supportFileSamples.slice(0, 40).map(stringValue)
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

function sanitizeIdentifiedCamera(camera) {
  if (!camera || typeof camera !== "object" || Array.isArray(camera)) {
    return null;
  }

  return {
    manufacturer: stringValue(camera.manufacturer).slice(0, 120),
    model: stringValue(camera.model).slice(0, 160),
    evidence: Array.isArray(camera.evidence)
      ? camera.evidence.slice(0, 10).map(stringValue)
      : [],
    isSupported: Boolean(camera.isSupported),
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

function optionalString(value) {
  return typeof value === "string" && value.length > 0 ? value.slice(0, 1000) : null;
}

function numberValue(value) {
  return Number.isFinite(value) ? value : 0;
}

function isSafeSettingPair(key, value) {
  return !isSensitiveSettingPair(key, value) && isUsefulSettingKey(key);
}

function isUsefulSettingKey(key) {
  const normalized = stringValue(key).toLowerCase();
  const usefulFragments = [
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

  if (!env.FEEDBACK_BUCKET && !env.FEEDBACK_KV) {
    console.log(body);
  }
}

function json(value, status = 200, request, env) {
  return new Response(JSON.stringify(value), {
    status,
    headers: responseHeaders(request, env),
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
