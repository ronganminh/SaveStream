import assert from "node:assert/strict";
import { beforeEach, test } from "node:test";

import worker, { sign } from "../src/index.js";

const SECRET = "test-secret-0123456789abcdef0123456789";
const ORIGIN = "https://media.savestream.online";

// --- fakes for the Workers runtime ------------------------------------------------

class MemoryCache {
  constructor() {
    this.entries = new Map();
  }
  async match(request) {
    const stored = this.entries.get(request.url);
    if (!stored) return undefined;
    const range = request.headers.get("Range");
    if (!range) return new Response(stored.body, { status: 200, headers: stored.headers });
    const [, from, to] = /bytes=(\d*)-(\d*)/.exec(range);
    const size = stored.body.length;
    const start = from === "" ? size - Number(to) : Number(from);
    const last = from === "" || to === "" ? size - 1 : Number(to);
    const headers = new Headers(stored.headers);
    headers.set("Content-Range", `bytes ${start}-${last}/${size}`);
    return new Response(stored.body.slice(start, last + 1), { status: 206, headers });
  }
  async put(request, response) {
    this.entries.set(request.url, {
      body: new Uint8Array(await response.arrayBuffer()),
      headers: response.headers,
    });
  }
}

function r2Object(key, bytes, contentType, withBody) {
  return {
    key,
    size: bytes.length,
    httpEtag: '"etag-1"',
    uploaded: new Date("2026-10-14T00:00:00Z"),
    httpMetadata: { contentType },
    ...(withBody ? { body: new Response(bytes).body } : {}),
  };
}

class FakeBucket {
  constructor(objects) {
    this.objects = objects;
    this.calls = [];
    this.failuresLeft = 0;
  }
  async head(key) {
    this.calls.push(["head", key]);
    const item = this.objects[key];
    return item ? r2Object(key, item.bytes, item.type, false) : null;
  }
  async get(key, options = {}) {
    this.calls.push(["get", key, options.range ?? null]);
    if (this.failuresLeft > 0) {
      this.failuresLeft -= 1;
      throw new Error("R2 internal error");
    }
    const item = this.objects[key];
    if (!item) return null;
    if (options.range) {
      const { offset, length } = options.range;
      return r2Object(key, item.bytes.slice(offset, offset + length), item.type, true);
    }
    return r2Object(key, item.bytes, item.type, true);
  }
}

const VIDEO_KEY = "users/u1/recordings/r1/a1.mp4";
const VIDEO = Uint8Array.from({ length: 1000 }, (_, i) => i % 251);
const AVATAR_ID = "0123456789abcdef0123456789abcdef";
const AVATAR = Uint8Array.from([0xff, 0xd8, 0xff, 1, 2, 3]);

let env;
let pending;
const ctx = { waitUntil: (promise) => pending.push(promise) };

beforeEach(() => {
  globalThis.caches = { default: new MemoryCache() };
  pending = [];
  env = {
    MEDIA_SIGNING_SECRET: SECRET,
    ALLOWED_ORIGINS: "https://savestream.online",
    MEDIA: new FakeBucket({
      [VIDEO_KEY]: { bytes: VIDEO, type: "video/mp4" },
      [`creator-avatars/${AVATAR_ID}`]: { bytes: AVATAR, type: "image/jpeg" },
      "creator-avatars/ffffffffffffffffffffffffffffffff": { bytes: AVATAR, type: "text/html" },
    }),
  };
});

const b64url = (text) =>
  Buffer.from(text).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function signedUrl({ expires = Math.floor(Date.now() / 1000) + 600, disposition = "" } = {}) {
  const path = `/o/${VIDEO_KEY.split("/").map(encodeURIComponent).join("/")}`;
  const cd = disposition ? b64url(disposition) : "";
  const s = await sign(SECRET, path, String(expires), cd);
  const query = new URLSearchParams({ e: String(expires), ...(cd ? { cd } : {}), s });
  return `${ORIGIN}${path}?${query}`;
}

const call = (url, init = {}) => worker.fetch(new Request(url, init), env, ctx);

// --- tests ------------------------------------------------------------------------------

test("signature matches the backend's test vector", async () => {
  // Same vector as backend/tests/test_media_urls.py.
  assert.equal(
    await sign("vector-secret", "/o/users/u/recordings/r/a.mp4", "1800000000", "YXR0YWNobWVudA"),
    "gc-9Bg0JJMjbr3677UCqL8566TEc1uAZ8qWdDAqIm-I",
  );
});

test("a signed link serves the file with its signed Content-Disposition", async () => {
  const disposition = 'attachment; filename="p.c.dat25_2026-10-14_2127.mp4"';
  const response = await call(await signedUrl({ disposition }));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Content-Disposition"), disposition);
  assert.equal(response.headers.get("Content-Type"), "video/mp4");
  assert.equal(response.headers.get("Accept-Ranges"), "bytes");
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), VIDEO);
  assert.match(response.headers.get("Cache-Control"), /^private, max-age=\d+$/);
});

test("expired, unsigned or edited links are refused", async () => {
  assert.equal((await call(await signedUrl({ expires: 1000 }))).status, 403);
  assert.equal((await call(`${ORIGIN}/o/${VIDEO_KEY}`)).status, 403);
  // Change the file name after signing.
  const url = new URL(await signedUrl({ disposition: 'attachment; filename="a.mp4"' }));
  url.searchParams.set("cd", b64url('attachment; filename="other.mp4"'));
  assert.equal((await call(url.toString())).status, 403);
  // Point a valid signature at another object.
  const other = new URL(await signedUrl());
  other.pathname = "/o/users/u2/recordings/r9/a9.mp4";
  assert.equal((await call(other.toString())).status, 403);
});

test("range requests return 206 with the right bytes, from R2 then from the edge cache", async () => {
  const url = await signedUrl();
  const first = await call(url, { headers: { Range: "bytes=100-199" } });
  assert.equal(first.status, 206);
  assert.equal(first.headers.get("Content-Range"), "bytes 100-199/1000");
  assert.equal(first.headers.get("X-Media-Cache"), "MISS");
  assert.deepEqual(new Uint8Array(await first.arrayBuffer()), VIDEO.slice(100, 200));
  await Promise.all(pending);

  const second = await call(url, { headers: { Range: "bytes=900-" } });
  assert.equal(second.status, 206);
  assert.equal(second.headers.get("X-Media-Cache"), "HIT");
  assert.deepEqual(new Uint8Array(await second.arrayBuffer()), VIDEO.slice(900));

  const suffix = await call(url, { headers: { Range: "bytes=-10" } });
  assert.equal(suffix.status, 206);
  assert.deepEqual(new Uint8Array(await suffix.arrayBuffer()), VIDEO.slice(990));
});

test("an unsatisfiable range is a 416", async () => {
  const response = await call(await signedUrl(), { headers: { Range: "bytes=5000-6000" } });
  assert.equal(response.status, 416);
  assert.equal(response.headers.get("Content-Range"), "bytes */1000");
});

test("transient R2 errors are retried", async () => {
  env.MEDIA.failuresLeft = 2;
  const response = await call(await signedUrl());
  assert.equal(response.status, 200);
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), VIDEO);
});

test("persistent R2 errors become a retryable 502, never a hang", async () => {
  env.MEDIA.failuresLeft = 99;
  const response = await call(await signedUrl());
  assert.equal(response.status, 502);
  assert.equal(response.headers.get("Retry-After"), "2");
});

test("CORS is granted to the web origin only", async () => {
  const url = await signedUrl();
  const allowed = await call(url, { headers: { Origin: "https://savestream.online" } });
  assert.equal(allowed.headers.get("Access-Control-Allow-Origin"), "https://savestream.online");
  const other = await call(url, { headers: { Origin: "https://evil.example" } });
  assert.equal(other.headers.get("Access-Control-Allow-Origin"), null);
});

test("avatars are public, cached, and only served as images", async () => {
  const first = await call(`${ORIGIN}/a/${AVATAR_ID}`);
  assert.equal(first.status, 200);
  assert.equal(first.headers.get("Content-Type"), "image/jpeg");
  assert.equal(first.headers.get("Cache-Control"), "public, max-age=86400");
  assert.deepEqual(new Uint8Array(await first.arrayBuffer()), AVATAR);
  await Promise.all(pending);
  const second = await call(`${ORIGIN}/a/${AVATAR_ID}`);
  assert.equal(second.headers.get("X-Media-Cache"), "HIT");

  assert.equal((await call(`${ORIGIN}/a/ffffffffffffffffffffffffffffffff`)).status, 404);
  assert.equal((await call(`${ORIGIN}/a/not-an-id`)).status, 404);
  assert.equal((await call(`${ORIGIN}/a/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`)).status, 404);
});

test("only GET and HEAD are allowed", async () => {
  assert.equal((await call(await signedUrl(), { method: "PUT", body: "x" })).status, 405);
  const head = await call(await signedUrl(), { method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(head.headers.get("Content-Length"), "1000");
});

test("a suffix range is served from R2 on a cache miss", async () => {
  const response = await call(await signedUrl(), { headers: { Range: "bytes=-10" } });
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("Content-Range"), "bytes 990-999/1000");
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), VIDEO.slice(990));
});
