const MANIFEST_KEY = "dashcam-offloader/latest.json";

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
