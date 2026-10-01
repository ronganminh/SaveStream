import assert from "node:assert/strict";
import test from "node:test";
import {
  formatDurationMinutes,
  formatRecordingHours,
  formatStorageGb,
} from "../src/lib/formatters.ts";

test("shared formatters avoid mixed-language units", () => {
  assert.equal(formatRecordingHours(50, "vi"), "50 giờ ghi hình");
  assert.equal(formatRecordingHours(50, "en"), "50 recording hours");
  assert.equal(formatDurationMinutes(68, "vi"), "1 giờ 8 phút");
  assert.equal(formatDurationMinutes(68, "en"), "1 h 8 min");
  assert.equal(formatStorageGb(18.4, "en"), "18.4 GB");
});
