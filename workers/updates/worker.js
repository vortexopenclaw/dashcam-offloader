const MANIFEST_KEY = "dashcam-offloader/latest.json";
const DESKTOP_UPDATE_PREFIX = "dashcam-offloader/desktop/";
const PRIVACY_POLICY_PATH = "/dashcam-offloader/privacy";
const SECURITY_TXT = `Contact: mailto:security@vortexradar.com
Contact: https://www.vortexradar.com/security-contact/
Preferred-Languages: en
Canonical: https://www.vortexradar.com/.well-known/security.txt
Policy: https://www.vortexradar.com/security-contact/
Expires: 2027-06-17T23:59:59Z
`;
const PRIVACY_POLICY_HTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Dashcam Offloader Privacy Policy</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      line-height: 1.55;
      margin: 0;
      padding: 32px 20px;
      background: Canvas;
      color: CanvasText;
    }
    main { max-width: 760px; margin: 0 auto; }
    h1 { font-size: 2rem; line-height: 1.15; margin: 0 0 8px; }
    h2 { font-size: 1.2rem; margin-top: 28px; }
    p, li { font-size: 1rem; }
    ul { padding-left: 1.4rem; }
    .updated { color: color-mix(in srgb, CanvasText 68%, Canvas); margin-top: 0; }
    code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
  </style>
</head>
<body>
  <main>
    <h1>Dashcam Offloader Privacy Policy</h1>
    <p class="updated">Last updated: August 7, 2026</p>

    <p>Dashcam Offloader is a Mac app that helps copy dashcam and camera footage from a memory card to a folder you choose. The app is designed to keep your footage local and to collect as little data as practical.</p>

    <h2>Local card scanning</h2>
    <p>When you scan a card, Dashcam Offloader reads folder names, filenames, file sizes, timestamps, selected safe camera metadata, and selected media technical details so it can identify the camera and plan downloads. This scanning happens on your Mac. Videos, photos, GPS traces, and other card contents are not uploaded during normal scanning or downloading.</p>

    <h2>Feedback and learning submissions</h2>
    <p>If you choose to send feedback or help add support for a dashcam, the app may send a sanitized submission to Vortex Radar's Cloudflare Worker endpoint. Submissions may include:</p>
    <ul>
      <li>Your feedback message and optional contact email or handle.</li>
      <li>The app version and submission timestamp.</li>
      <li>User-entered camera manufacturer, model, channel count, channel descriptions, and notes.</li>
      <li>Only when you opt in, anonymous scan statistics such as file counts, extension counts, recording-mode counts, timestamp-source counts, camera-profile candidates, and aggregate media technical summaries.</li>
    </ul>

    <h2>What we do not upload</h2>
    <p>Feedback and learning submissions are designed not to upload videos, photos, GPS traces, route data, serial numbers, Wi-Fi details, cloud account fields, device IDs, full settings dumps, license plates, source names, folder paths, filenames, or other personally identifying information. The app sanitizes submissions before upload, and the receiving Worker runs a second sanitization pass before storage.</p>

    <h2>Where submissions are stored</h2>
    <p>Feedback and learning submissions are received by a Cloudflare Worker and stored privately in Cloudflare storage controlled by Vortex Radar. Stored submissions are used to troubleshoot the app, improve camera detection, add or refine dashcam profiles, and respond to users who provide contact information.</p>

    <h2>Sharing</h2>
    <p>We do not sell Dashcam Offloader feedback or learning data. We may publish camera-profile improvements, documentation, or generic examples derived from submissions, but we avoid publishing private user data or anything that identifies a person, vehicle, route, or device.</p>

    <h2>Retention</h2>
    <p>Submissions may be retained while they remain useful for troubleshooting, security review, camera-profile development, or audit history. You can ask for a submission tied to your contact information to be deleted.</p>

    <h2>Security</h2>
    <p>The feedback endpoint uses HTTPS, payload-size limits, rate limiting, server-side validation, and sanitization. Security reports can be sent using the contact information in <code>/.well-known/security.txt</code>.</p>

    <h2>Contact</h2>
    <p>For privacy or security questions, contact <a href="mailto:security@vortexradar.com">security@vortexradar.com</a> or use <a href="https://www.vortexradar.com/security-contact/">https://www.vortexradar.com/security-contact/</a>.</p>
  </main>
</body>
</html>
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

function privacyPolicyResponse(method) {
  return new Response(method === "HEAD" ? null : PRIVACY_POLICY_HTML, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
      "access-control-allow-origin": "*",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff",
    },
  });
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "access-control-allow-origin": "*",
    },
  });
}

function notFound() {
  return jsonResponse({ error: "not_found" }, 404);
}

async function loadManifest(env) {
  const object = await env.UPDATES_BUCKET.get(MANIFEST_KEY);
  if (!object) {
    return null;
  }
  return object.json();
}

function responseHeaders(object, contentType) {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("cache-control", "public, max-age=300");
  headers.set("access-control-allow-origin", "*");
  if (contentType) {
    headers.set("content-type", contentType);
  }
  return headers;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET, HEAD, OPTIONS",
          "access-control-allow-headers": "content-type",
        },
      });
    }

    if (!["GET", "HEAD"].includes(request.method)) {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    if (path === "/.well-known/security.txt") {
      return securityTxtResponse(request.method);
    }

    if (path === PRIVACY_POLICY_PATH) {
      return privacyPolicyResponse(request.method);
    }

    if (path === "/" || path === "/healthz") {
      return jsonResponse({ ok: true, service: "dashcam-offloader-updates" });
    }

    if (path === "/dashcam-offloader/latest.json") {
      const object = await env.UPDATES_BUCKET.get(MANIFEST_KEY);
      if (!object) {
        return notFound();
      }
      return new Response(request.method === "HEAD" ? null : object.body, {
        headers: responseHeaders(object, "application/json; charset=utf-8"),
      });
    }

    if (path.startsWith("/dashcam-offloader/desktop/")) {
      const assetName = decodeURIComponent(path.slice("/dashcam-offloader/desktop/".length));
      if (!assetName || assetName.includes("/") || assetName.includes("\\")) {
        return notFound();
      }
      const object = await env.UPDATES_BUCKET.get(`${DESKTOP_UPDATE_PREFIX}${assetName}`);
      if (!object) {
        return notFound();
      }
      const contentType = assetName.endsWith(".yml")
        ? "text/yaml; charset=utf-8"
        : "application/octet-stream";
      return new Response(request.method === "HEAD" ? null : object.body, {
        headers: responseHeaders(object, contentType),
      });
    }

    if (path === "/dashcam-offloader/download/latest") {
      const manifest = await loadManifest(env);
      if (!manifest?.assetKey) {
        return notFound();
      }

      const object = await env.UPDATES_BUCKET.get(manifest.assetKey);
      if (!object) {
        return notFound();
      }

      const headers = responseHeaders(object, "application/zip");
      headers.set("content-disposition", `attachment; filename="${manifest.assetName ?? "Dashcam-Offloader.zip"}"`);
      return new Response(request.method === "HEAD" ? null : object.body, { headers });
    }

    const downloadPrefix = "/dashcam-offloader/download/";
    if (path.startsWith(downloadPrefix)) {
      const assetName = decodeURIComponent(path.slice(downloadPrefix.length));
      if (!assetName || assetName.includes("/") || assetName.includes("\\")) {
        return notFound();
      }

      const object = await env.UPDATES_BUCKET.get(`dashcam-offloader/releases/${assetName}`);
      if (!object) {
        return notFound();
      }

      const headers = responseHeaders(object, "application/zip");
      headers.set("content-disposition", `attachment; filename="${assetName}"`);
      return new Response(request.method === "HEAD" ? null : object.body, { headers });
    }

    return notFound();
  },
};
