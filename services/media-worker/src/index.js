// SaveStream media delivery (media.savestream.online).
//
// Serves recordings and cached creator avatars from the R2 bucket through a
// Worker binding instead of the S3 API endpoint (<account>.r2.cloudflarestorage.com),
// which answered 503 to range requests and downloads. Responses come from
// Cloudflare's edge cache when possible.
//
//   GET /o/<object key>?e=<unix expiry>&cd=<base64url Content-Disposition>&s=<sig>
//       A recording. The API signs every link (HMAC-SHA256 with
//       MEDIA_SIGNING_SECRET, shared with the backend) over the path, the expiry
//       and the optional Content-Disposition, so links expire and cannot be
//       edited into another file or name. Range requests are supported.
//   GET /a/<32 hex id>
//       A cached creator avatar (public, like /v1/public/creator-avatars/<id>).
//   GET /healthz
//
// Bindings: MEDIA (R2 bucket), MEDIA_SIGNING_SECRET (secret),
// ALLOWED_ORIGINS (comma-separated web origins allowed to read with CORS).

const RECORDING_PREFIX = "/o/";
const AVATAR_PREFIX = "/a/";
const AVATAR_KEY_PREFIX = "creator-avatars/";
const AVATAR_ID = /^[0-9a-f]{32}$/;
const AVATAR_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
// Workers Cache API objects are limited to 512 MB and a background cache fill
// must finish within the waitUntil budget, so only files up to 256 MB are
// copied into the edge cache. Larger ones are served straight from the R2
// binding (still not through the S3 endpoint).
const CACHE_MAX_BYTES = 256 * 1024 * 1024;
const CACHE_TTL_SECONDS = 24 * 60 * 60;
const R2_ATTEMPTS = 3;

const encoder = new TextEncoder();

export function base64url(bytes) {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64url(value) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded + "=".repeat((4 - (padded.length % 4)) % 4));
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

/** Same canonical string as backend app.infrastructure.storage.media_urls. */
export function canonical(path, expires, disposition) {
  return `${path}\n${expires}\n${disposition}`;
}

async function hmacKey(secret) {
  return crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export async function sign(secret, path, expires, disposition = "") {
  const key = await hmacKey(secret);
  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(canonical(path, expires, disposition)));
  return base64url(mac);
}

async function verify(secret, path, expires, disposition, signature) {
  let mac;
  try {
    mac = fromBase64url(signature);
  } catch {
    return false;
  }
  const key = await hmacKey(secret);
  // crypto.subtle.verify compares in constant time.
  return crypto.subtle.verify("HMAC", key, mac, encoder.encode(canonical(path, expires, disposition)));
}

function text(status, body, extra = {}) {
  return new Response(body, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store", ...extra },
  });
}

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin");
  const allowed = (env.ALLOWED_ORIGINS || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (!origin || !allowed.includes(origin)) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Expose-Headers": "Content-Length, Content-Range, Accept-Ranges, ETag",
    Vary: "Origin",
  };
}

async function r2Get(bucket, key, options) {
  let lastError;
  for (let attempt = 1; attempt <= R2_ATTEMPTS; attempt += 1) {
    try {
      return await bucket.get(key, options);
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 150 * attempt));
    }
  }
  throw lastError;
}

async function r2Head(bucket, key) {
  let lastError;
  for (let attempt = 1; attempt <= R2_ATTEMPTS; attempt += 1) {
    try {
      return await bucket.head(key);
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 150 * attempt));
    }
  }
  throw lastError;
}

function parseRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header || "");
  if (!match || (match[1] === "" && match[2] === "")) return null;
  let start;
  let end;
  if (match[1] === "") {
    const suffix = Number(match[2]);
    start = Math.max(0, size - suffix);
    end = size - 1;
  } else {
    start = Number(match[1]);
    end = match[2] === "" ? size - 1 : Math.min(Number(match[2]), size - 1);
  }
  if (start > end || start >= size) return "unsatisfiable";
  return { offset: start, length: end - start + 1 };
}

function objectHeaders(object, contentType) {
  const headers = new Headers();
  headers.set("Content-Type", contentType || object.httpMetadata?.contentType || "application/octet-stream");
  headers.set("Accept-Ranges", "bytes");
  headers.set("ETag", object.httpEtag);
  headers.set("Last-Modified", object.uploaded.toUTCString());
  headers.set("X-Content-Type-Options", "nosniff");
  return headers;
}

/**
 * Serve `key` for this request: edge cache first, then the R2 binding.
 * Range requests are answered from the cached full object when present;
 * otherwise from R2 with the requested range, while (for objects that fit in
 * the cache) the full object is cached in the background.
 */
async function serveObject(request, env, ctx, { key, cacheUrl, contentType, browserCache, extraHeaders }) {
  const cacheKey = new Request(cacheUrl, { method: "GET" });
  const range = request.headers.get("Range");

  const cached = await caches.default.match(
    new Request(cacheUrl, { headers: range ? { Range: range } : {} }),
  );
  // A range request must get a 206 from the cache; anything else goes to R2.
  if (cached && (!range || cached.status === 206)) {
    const response = new Response(request.method === "HEAD" ? null : cached.body, cached);
    for (const [name, value] of Object.entries(extraHeaders)) response.headers.set(name, value);
    response.headers.set("Cache-Control", browserCache);
    response.headers.set("X-Media-Cache", "HIT");
    return response;
  } else if (cached) {
    cached.body?.cancel();
  }

  const finish = (headers) => {
    for (const [name, value] of Object.entries(extraHeaders)) headers.set(name, value);
    headers.set("Cache-Control", browserCache);
    headers.set("X-Media-Cache", "MISS");
    return headers;
  };

  if (range) {
    const meta = await r2Head(env.MEDIA, key);
    if (meta === null) return text(404, "Not found");
    const size = meta.size;
    const headers = finish(objectHeaders(meta, contentType));
    const parsed = parseRange(range, size);
    if (parsed === "unsatisfiable") {
      headers.set("Content-Range", `bytes */${size}`);
      return new Response(null, { status: 416, headers });
    }
    if (size <= CACHE_MAX_BYTES) ctx.waitUntil(fillCache(env, key, cacheKey, contentType));
    if (parsed) {
      const part = await r2Get(env.MEDIA, key, { range: parsed });
      if (part === null) return text(404, "Not found");
      headers.set("Content-Range", `bytes ${parsed.offset}-${parsed.offset + parsed.length - 1}/${size}`);
      headers.set("Content-Length", String(parsed.length));
      return new Response(request.method === "HEAD" ? null : part.body, { status: 206, headers });
    }
    // Unparseable Range header: ignore it and send the whole object below.
  }

  if (request.method === "HEAD") {
    const meta = await r2Head(env.MEDIA, key);
    if (meta === null) return text(404, "Not found");
    const headers = finish(objectHeaders(meta, contentType));
    headers.set("Content-Length", String(meta.size));
    return new Response(null, { status: 200, headers });
  }

  const object = await r2Get(env.MEDIA, key, { onlyIf: request.headers });
  if (object === null) return text(404, "Not found");
  const headers = finish(objectHeaders(object, contentType));
  if (!object.body) {
    // onlyIf precondition failed (If-None-Match / If-Modified-Since).
    return new Response(null, { status: 304, headers });
  }
  headers.set("Content-Length", String(object.size));
  if (object.size <= CACHE_MAX_BYTES) {
    const [forClient, forCache] = object.body.tee();
    ctx.waitUntil(putCache(cacheKey, forCache, object, contentType));
    return new Response(forClient, { status: 200, headers });
  }
  return new Response(object.body, { status: 200, headers });
}

async function putCache(cacheKey, body, object, contentType) {
  const headers = objectHeaders(object, contentType);
  headers.set("Content-Length", String(object.size));
  headers.set("Cache-Control", `public, max-age=${CACHE_TTL_SECONDS}`);
  await caches.default.put(cacheKey, new Response(body, { status: 200, headers }));
}

// Keys being copied into the cache by this isolate; a player fires several
// range requests at once and only one should fill.
const filling = new Set();

async function fillCache(env, key, cacheKey, contentType) {
  if (filling.has(key)) return;
  filling.add(key);
  try {
    if (await caches.default.match(cacheKey)) return;
    const object = await r2Get(env.MEDIA, key, {});
    if (object && object.body) await putCache(cacheKey, object.body, object, contentType);
  } finally {
    filling.delete(key);
  }
}

async function handleRecording(request, env, ctx, url) {
  if (!env.MEDIA_SIGNING_SECRET) return text(503, "Media signing is not configured");
  const path = url.pathname;
  const expires = url.searchParams.get("e") || "";
  const dispositionParam = url.searchParams.get("cd") || "";
  const signature = url.searchParams.get("s") || "";
  if (!/^\d{1,12}$/.test(expires) || !signature) return text(403, "Invalid link");
  if (Number(expires) < Math.floor(Date.now() / 1000)) return text(403, "This link has expired");
  if (!(await verify(env.MEDIA_SIGNING_SECRET, path, expires, dispositionParam, signature))) {
    return text(403, "Invalid link");
  }
  let key;
  try {
    key = decodeURIComponent(path.slice(RECORDING_PREFIX.length));
  } catch {
    return text(400, "Bad path");
  }
  if (!key || key.includes("..")) return text(400, "Bad path");

  const extraHeaders = { ...corsHeaders(request, env) };
  if (dispositionParam) {
    extraHeaders["Content-Disposition"] = new TextDecoder().decode(fromBase64url(dispositionParam));
  }
  const maxAge = Math.max(0, Number(expires) - Math.floor(Date.now() / 1000));
  return serveObject(request, env, ctx, {
    key,
    // One cache entry per file, whatever the signature or file name.
    cacheUrl: `${url.origin}/__cache/o/${encodeURIComponent(key)}`,
    contentType: key.endsWith(".mp4") ? "video/mp4" : undefined,
    browserCache: `private, max-age=${maxAge}`,
    extraHeaders,
  });
}

async function handleAvatar(request, env, ctx, url) {
  const id = url.pathname.slice(AVATAR_PREFIX.length);
  if (!AVATAR_ID.test(id)) return text(404, "Not found");
  const key = `${AVATAR_KEY_PREFIX}${id}`;
  const response = await serveObject(request, env, ctx, {
    key,
    cacheUrl: `${url.origin}/__cache/a/${id}`,
    contentType: undefined,
    browserCache: "public, max-age=86400",
    extraHeaders: { "Access-Control-Allow-Origin": "*", "Cross-Origin-Resource-Policy": "cross-origin" },
  });
  const type = (response.headers.get("Content-Type") || "").split(";")[0].trim().toLowerCase();
  if (response.ok && !AVATAR_TYPES.has(type)) return text(404, "Not found");
  return response;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          ...corsHeaders(request, env),
          "Access-Control-Allow-Methods": "GET, HEAD",
          "Access-Control-Allow-Headers": "Range",
          "Access-Control-Max-Age": "86400",
        },
      });
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return text(405, "Method not allowed", { Allow: "GET, HEAD" });
    }
    try {
      if (url.pathname === "/healthz") return text(200, "ok");
      if (url.pathname.startsWith(RECORDING_PREFIX)) return await handleRecording(request, env, ctx, url);
      if (url.pathname.startsWith(AVATAR_PREFIX)) return await handleAvatar(request, env, ctx, url);
      return text(404, "Not found");
    } catch (error) {
      console.error("media error", url.pathname, error);
      return text(502, "Storage is temporarily unavailable, please try again", { "Retry-After": "2" });
    }
  },
};
