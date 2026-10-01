import assert from "node:assert/strict";
import test from "node:test";
import { canAccessRoute, getRouteAccess } from "../src/lib/app-config.ts";

test("admin routes require an authenticated admin", () => {
  const access = getRouteAccess("/admin/system");
  assert.equal(access.visibility, "admin");
  assert.equal(access.indexable, false);
  assert.equal(canAccessRoute(access, { authenticated: true, role: "user" }), false);
  assert.equal(canAccessRoute(access, { authenticated: true, role: "admin" }), true);
});

test("public pricing remains indexable without auth", () => {
  const access = getRouteAccess("/pricing");
  assert.equal(access.visibility, "public");
  assert.equal(access.indexable, true);
  assert.equal(canAccessRoute(access, { authenticated: false, role: "guest" }), true);
});
