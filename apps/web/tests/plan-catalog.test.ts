import assert from "node:assert/strict";
import test from "node:test";
import { planCatalog } from "../src/lib/plan-catalog.ts";

test("plan catalog keeps approved Pro limits in one source", () => {
  assert.equal(planCatalog.pro.priceMonthlyUsd, 9.99);
  assert.equal(planCatalog.pro.priceYearlyUsd, null);
  assert.equal(planCatalog.pro.quotas.recordingHours, 50);
  assert.equal(planCatalog.pro.quotas.monitoredChannels, 5);
  assert.equal(planCatalog.pro.quotas.simultaneousRecordings, 2);
  assert.equal(planCatalog.pro.quotas.downloadGb, 100);
  assert.equal(planCatalog.pro.quotas.retentionDays, 30);
});
