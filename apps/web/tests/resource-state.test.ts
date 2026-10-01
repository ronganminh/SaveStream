import assert from "node:assert/strict";
import test from "node:test";
import {
  channelLifecycle,
  isTerminalRecordingLifecycle,
  recordingLifecycle,
} from "../src/domain/resource-state.ts";

test("recording lifecycle distinguishes partial and expiring recordings", () => {
  const partial = {
    status: "Error",
    partialDuration: "47 minutes",
    expiresDays: 27,
  } as never;
  const expiring = {
    status: "Ready",
    expiresDays: 3,
  } as never;
  assert.equal(recordingLifecycle(partial), "partial");
  assert.equal(recordingLifecycle(expiring), "expiring");
  assert.equal(isTerminalRecordingLifecycle("partial"), true);
});

test("channel lifecycle normalizes recording and paused states", () => {
  assert.equal(channelLifecycle({ status: "Recording" } as never), "live");
  assert.equal(channelLifecycle({ status: "Paused" } as never), "paused");
});
