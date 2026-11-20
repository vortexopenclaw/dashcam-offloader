import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { FeedbackRateLimiter } from "./worker.js";
import * as feedback from "./worker.js";

const { sanitizeFeedback, sanitizeScan, validateFeedback } = feedback;
// Identity fallback lets this file load (and fail meaningfully) against an unpatched Worker.
const rateLimitClientKey = feedback.rateLimitClientKey ?? ((address) => address);

const HOST_PATH = "/Users/example/Dashcam Card";
const COORDINATES = "37.774929,-122.419416";

function environment() {
  const stored = new Map();
  const limiters = new Map();
  return {
    stored,
    limiters,
    RATE_LIMIT_SALT: "s".repeat(32),
    FEEDBACK_KV: { async put(key, value) { stored.set(key, value); } },
    FEEDBACK_RATE_LIMITER: {
      idFromName: (name) => name,
      get(name) {
        if (!limiters.has(name)) {
          const data = new Map();
          const storage = { get: async (key) => data.get(key), put: async (key, value) => { data.set(key, value); } };
          limiters.set(name, new FeedbackRateLimiter({ storage: { transaction: (run) => run(storage) } }));
        }
        return limiters.get(name);
      },
    },
  };
}

function post(body, ip = "203.0.113.7") {
  return new Request("https://feedback.example/feedback", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

test("free-form scan fields cannot carry host paths or coordinates into storage", () => {
  const scan = sanitizeScan({
    identifiedCamera: { manufacturer: `${HOST_PATH}/maker`, model: `Model at ${COORDINATES}`, isSupported: true },
    candidates: [{ profileID: "viofo-a229-pro", profileName: "VIOFO A229 Pro", score: 90, confidence: `high ${HOST_PATH}` }],
    videoSpecSummaries: [{ extensionLowercased: `${HOST_PATH}/clip.mp4`, fileCount: 1 }],
    extensionCounts: { mp4: 3, "passport.jane-example-1984": 1, janeexample1984: 1, "[none]": 2 },
    unrecognizedExtensionCounts: { janeexample1984: 1, thm: 2 },
    directorySummaries: [{ path: "DCIM", extensionCounts: { mp4: 1, janeexample1984: 1 } }],
    folderSummaries: [{ path: "DCIM", extensionCounts: { mp4: 1, janeexample1984: 1 } }],
  });
  const stored = JSON.stringify(scan);
  assert.equal(stored.includes(HOST_PATH.slice(0, 7)), false, stored);
  assert.equal(stored.includes("37.774929"), false, stored);
  assert.equal(stored.includes("janeexample1984"), false, stored);
  assert.equal(scan.identifiedCamera, null);
  assert.equal(scan.candidates[0].confidence, "");
  assert.equal(scan.videoSpecSummaries[0].extensionLowercased, "");
  assert.deepEqual(scan.extensionCounts, { mp4: 3 });
  assert.deepEqual(scan.unrecognizedExtensionCounts, { thm: 2 });
  assert.deepEqual(scan.directorySummaries[0].extensionCounts, { mp4: 1 });
  assert.deepEqual(scan.folderSummaries[0].extensionCounts, { mp4: 1 });
});

test("ordinary camera identity, confidence and extension values are still retained", () => {
  const scan = sanitizeScan({
    identifiedCamera: { manufacturer: "VIOFO", model: "A229 Pro (3CH)", isSupported: true },
    candidates: [{ profileID: "viofo-a229-pro", profileName: "VIOFO A229 Pro", score: 90, confidence: "high" }],
    videoSpecSummaries: [{ extensionLowercased: "MP4", fileCount: 1 }],
    extensionCounts: { mp4: 3, JPG: 1, m2ts: 1 },
  });
  assert.deepEqual(scan.identifiedCamera, { manufacturer: "VIOFO", model: "A229 Pro (3CH)", evidence: [], isSupported: true });
  assert.equal(scan.candidates[0].confidence, "high");
  assert.equal(scan.videoSpecSummaries[0].extensionLowercased, "mp4");
  assert.deepEqual(scan.extensionCounts, { mp4: 3, jpg: 1, m2ts: 1 });
});

test("app version and timestamp are bounded technical values", () => {
  const record = sanitizeFeedback({
    kind: "bug",
    message: "It crashed",
    appVersion: `0.1.44 ${HOST_PATH} ${"x".repeat(5000)}`,
    createdAt: { toString: () => HOST_PATH },
  });
  assert.equal(record.appVersion, "");
  assert.equal(record.createdAt, "");
  const ordinary = sanitizeFeedback({ kind: "bug", message: "ok", appVersion: "0.1.44 213 76f37b9", createdAt: "2026-11-19T10:11:12Z" });
  assert.equal(ordinary.appVersion, "0.1.44 213 76f37b9");
  assert.equal(ordinary.createdAt, "2026-11-19T10:11:12Z");
});

test("malformed scan arrays are rejected or ignored instead of crashing the Worker", async () => {
  for (const scan of [
    { candidates: [null] },
    { candidates: ["text", 7] },
    { scanDiagnostics: [null] },
    { scanDiagnostics: [[]] },
    { mediaFileSamples: [null], videoSpecSummaries: [null], settingSnapshots: [null], directorySummaries: [null], folderSummaries: [null] },
  ]) {
    assert.doesNotThrow(() => validateFeedback({ kind: "bug", message: "x", scan }), JSON.stringify(scan));
    const env = environment();
    const response = await worker.fetch(post({ kind: "bug", message: "x", scan }), env);
    assert.equal(response.status, 202, JSON.stringify(scan));
    const record = JSON.parse([...env.stored.values()][0]);
    assert.deepEqual(record.scan.candidates, []);
    assert.deepEqual(record.scan.scanDiagnostics, []);
  }
});

test("non-object training and scalar scan payloads never throw", async () => {
  for (const body of [
    { kind: "bug", message: "x", training: "text" },
    { kind: "bug", message: "x", training: 5 },
    { kind: "bug", message: "x", scan: 5 },
    { kind: "bug", message: "x", scan: "text" },
    { kind: "bug", message: "x", contact: 12345 },
  ]) {
    const response = await worker.fetch(post(body), environment());
    assert.ok([202, 400].includes(response.status), `${JSON.stringify(body)} -> ${response.status}`);
  }
});

test("rotating addresses inside one IPv6 /64 shares a single rate-limit bucket", async () => {
  assert.equal(rateLimitClientKey("2001:db8:1:2:aaaa:bbbb:cccc:dddd"), rateLimitClientKey("2001:db8:1:2::1"));
  assert.equal(rateLimitClientKey("2001:DB8:1:2::1"), rateLimitClientKey("2001:db8:0001:0002:ffff::"));
  assert.notEqual(rateLimitClientKey("2001:db8:1:2::1"), rateLimitClientKey("2001:db8:1:3::1"));
  assert.notEqual(rateLimitClientKey("2001:db8::1"), rateLimitClientKey("2001:db8:1::1"));
  assert.equal(rateLimitClientKey("203.0.113.7"), "203.0.113.7");
  assert.notEqual(rateLimitClientKey("203.0.113.7"), rateLimitClientKey("203.0.113.8"));
  assert.equal(rateLimitClientKey("::ffff:203.0.113.7"), "203.0.113.7");
  assert.equal(rateLimitClientKey("not an address"), "not an address");

  const env = environment();
  let accepted = 0;
  for (let index = 0; index < 60; index += 1) {
    const response = await worker.fetch(post({ kind: "bug", message: "x" }, `2001:db8:1:2::${(index + 1).toString(16)}`), env);
    if (response.status === 202) accepted += 1;
  }
  assert.equal(accepted, 20);
  assert.equal(env.stored.size, 20);
});

test("browser-originated posts are refused unless the origin is allowlisted", async () => {
  const req = (origin) => new Request("https://feedback.example/feedback", {
    method: "POST", headers: { "Content-Type": "application/json", ...(origin ? { Origin: origin } : {}) }, body: "{}",
  });
  assert.equal(feedback.originPermitted(req(), {}), true, "native app (no Origin)");
  assert.equal(feedback.originPermitted(req("https://evil.example"), {}), false);
  assert.equal(feedback.originPermitted(req("null"), {}), false);
  assert.equal(feedback.originPermitted(req("https://ok.example"), { ALLOWED_ORIGINS: "https://ok.example" }), true);
  const response = await worker.fetch(req("https://evil.example"), {});
  assert.equal(response.status, 403);
  assert.equal((await response.json()).error, "forbidden_origin");
});
