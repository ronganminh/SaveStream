import assert from "node:assert/strict";
import test from "node:test";
import {
  analyticsEventNames,
  buildAnalyticsEnvelope,
} from "../src/lib/analytics-schema.ts";

test("analytics schema contains the product-validation events", () => {
  assert.ok(analyticsEventNames.includes("landing_cta_clicked"));
  assert.ok(analyticsEventNames.includes("channel_added"));
  assert.ok(analyticsEventNames.includes("download_clicked"));
  assert.ok(analyticsEventNames.includes("support_opened"));
});

test("demo analytics is marked and PII-shaped property keys are rejected", () => {
  const event = buildAnalyticsEnvelope("demo", "plan_selected", {
    plan: "pro",
    source: "pricing",
  });
  assert.equal(event.demo, true);
  assert.equal(event.mode, "demo");
  assert.throws(() =>
    buildAnalyticsEnvelope("demo", "plan_selected", {
      plan: "pro",
      source: "pricing",
      email: "private@example.com",
    } as never),
  );
});
