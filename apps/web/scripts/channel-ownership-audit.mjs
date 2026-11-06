// Channel ownership on the website (owner decision 2026-11-06): the
// ownership checkbox is required on Add channel, verifying with the bio code
// is optional unless the API says `verification_required`, blocked channels
// can't be resumed, and legacy web channels get a gentle prompt.
// Backend contract: PRs #258 / #260 (WatchResponse.ownership_basis, .blocked,
// OWNERSHIP_ATTESTATION_REQUIRED, CHANNEL_BLOCKED, admin channel-blocks).
//
// The rules in src/lib/channel-ownership.ts are tested by running them (Node
// strips the TypeScript types); the components are checked by source.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];
const test = (label, fn) => {
  try {
    fn();
    console.log(`ok   ${label}`);
  } catch (error) {
    console.log(`FAIL ${label}`);
    failures.push(`${label}: ${error.message}`);
  }
};
const block = (file, start, end) => {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to >= 0, `${file}: could not locate ${start}`);
  return source.slice(from, to);
};

const rules = await import(pathToFileURL(path.join(root, "src/lib/channel-ownership.ts")).href);
const {
  OWNERSHIP_STATEMENT,
  CHANNEL_BLOCKED_TEXT,
  LEGACY_ATTESTATION_PROMPT,
  ownershipBadgeKind,
  needsVerificationReminder,
  needsLegacyAttestation,
  verificationIsRequired,
  autoCheckDelay,
  AUTO_CHECK_MIN_INTERVAL_MS,
  AUTO_CHECK_WINDOW_MS,
} = rules;

// --- Copy ------------------------------------------------------------------
test("checkbox label is the exact statement", () => {
  assert.equal(
    OWNERSHIP_STATEMENT,
    "I own this channel or have the creator's permission to record it.",
  );
});
test("blocked text", () => {
  assert.equal(
    CHANNEL_BLOCKED_TEXT,
    "Recording stopped for this channel on your account after a report. Contact support if you think this is a mistake.",
  );
});
test("legacy prompt text", () => {
  assert.equal(
    LEGACY_ATTESTATION_PROMPT,
    "Please confirm you own this channel or have the creator's permission to record it.",
  );
});

// --- Badges ----------------------------------------------------------------
const day = "2026-11-06T00:00:00Z";
test("badge: blocked wins over everything", () => {
  assert.equal(ownershipBadgeKind({ blocked: true, ownerVerifiedAt: day }), "blocked");
  assert.equal(ownershipBadgeKind({ blocked: true, verificationRequired: true }), "blocked");
});
test("badge: verified", () => {
  assert.equal(ownershipBadgeKind({ ownerVerifiedAt: day, ownershipBasis: null }), "verified");
});
test("badge: verification required by the API (web flag on)", () => {
  assert.equal(
    ownershipBadgeKind({ verificationRequired: true, ownershipBasis: "web_attested" }),
    "verify_to_record",
  );
});
test("badge: web-attested channel is neutral 'Not verified', no deadline", () => {
  assert.equal(
    ownershipBadgeKind({
      verificationRequired: false,
      verificationDueAt: day,
      ownershipBasis: "web_attested",
    }),
    "not_verified",
  );
  assert.equal(
    ownershipBadgeKind({ verificationDueAt: day, ownershipBasis: "web_attested_legacy" }),
    "not_verified",
  );
});
test("badge: older app channel in its grace period keeps 'Verify by'", () => {
  assert.equal(ownershipBadgeKind({ verificationDueAt: day, ownershipBasis: null }), "verify_by");
});
test("reminder only for channels that still need the bio code", () => {
  assert.equal(needsVerificationReminder({ verificationRequired: true }), true);
  assert.equal(needsVerificationReminder({ verificationDueAt: day }), true);
  assert.equal(
    needsVerificationReminder({ verificationDueAt: day, ownershipBasis: "web_attested" }),
    false,
  );
  assert.equal(needsVerificationReminder({ ownerVerifiedAt: day }), false);
  assert.equal(needsVerificationReminder({ blocked: true, verificationRequired: true }), false);
});
test("verification required only when the API says so", () => {
  assert.equal(verificationIsRequired({ verificationRequired: true }), true);
  assert.equal(verificationIsRequired({ verificationRequired: false }), false);
  assert.equal(verificationIsRequired({ verificationRequired: true, ownerVerifiedAt: day }), false);
});

// --- Legacy prompt ---------------------------------------------------------
test("legacy prompt: unverified web_attested_legacy only", () => {
  assert.equal(needsLegacyAttestation({ ownershipBasis: "web_attested_legacy" }), true);
  assert.equal(
    needsLegacyAttestation({ ownershipBasis: "web_attested_legacy", ownerVerifiedAt: day }),
    false,
  );
  assert.equal(needsLegacyAttestation({ ownershipBasis: "web_attested" }), false);
  assert.equal(needsLegacyAttestation({ ownershipBasis: null }), false);
  assert.equal(
    needsLegacyAttestation({ ownershipBasis: "web_attested_legacy", blocked: true }),
    false,
  );
});

// --- Auto re-check ---------------------------------------------------------
const now = 1_000_000;
test("auto-check: off without a window", () => {
  assert.equal(autoCheckDelay({ now, lastCheckAt: null, windowEndsAt: null }), null);
});
test("auto-check: right away when nothing was checked yet", () => {
  assert.equal(autoCheckDelay({ now, lastCheckAt: null, windowEndsAt: now + 1000 }), 0);
});
test("auto-check: at most every 15 s", () => {
  assert.equal(AUTO_CHECK_MIN_INTERVAL_MS, 15_000);
  assert.equal(
    autoCheckDelay({ now, lastCheckAt: now - 5_000, windowEndsAt: now + AUTO_CHECK_WINDOW_MS }),
    10_000,
  );
});
test("auto-check: respects a longer retry_after_seconds", () => {
  assert.equal(
    autoCheckDelay({
      now,
      lastCheckAt: now,
      retryAfterSeconds: 40,
      windowEndsAt: now + AUTO_CHECK_WINDOW_MS,
    }),
    40_000,
  );
});
test("auto-check: stops after 5 min", () => {
  assert.equal(AUTO_CHECK_WINDOW_MS, 300_000);
  assert.equal(autoCheckDelay({ now, lastCheckAt: now - 1_000, windowEndsAt: now }), null);
  assert.equal(autoCheckDelay({ now, lastCheckAt: now, windowEndsAt: now + 10_000 }), null);
});
test("auto-check: keeps the last checks for the user", () => {
  assert.equal(
    autoCheckDelay({ now, lastCheckAt: null, windowEndsAt: now + 60_000, checksLeft: 3 }),
    null,
  );
  assert.equal(
    autoCheckDelay({ now, lastCheckAt: null, windowEndsAt: now + 60_000, checksLeft: 10 }),
    0,
  );
});

// --- Components (source checks) ---------------------------------------------
const components = "src/components/app-components.tsx";
const addChannel = block(
  components,
  "export function AddChannelDialog",
  "export function UpgradeDialog",
);
test("Add channel: required box, label, AUP link, always sends owner_attested", () => {
  assert.ok(addChannel.includes("{OWNERSHIP_STATEMENT}"));
  assert.ok(addChannel.includes("required"));
  assert.ok(addChannel.includes('to="/acceptable-use"'));
  assert.ok(addChannel.includes("owner_attested: true,"));
  assert.ok(!addChannel.includes("(optional)</span>"), "the box is no longer optional");
  assert.ok(!addChannel.includes("...(ownerAttested ?"), "owner_attested is always sent");
});
test("Add channel: submit disabled until ticked; API error shown inline", () => {
  assert.ok(
    addChannel.includes('disabled={state !== "found" || !ownerAttested || phase === "submitting"}'),
  );
  assert.ok(addChannel.includes("isOwnershipAttestationError(error)"));
  assert.ok(addChannel.includes('id="add-channel-owner-error"'));
  assert.ok(addChannel.includes('role="alert"'));
});
test("Add channel: verify step only when the API requires it, else optional", () => {
  assert.ok(
    addChannel.includes("setCreatedNeedsVerification(Boolean(watch.verification_required))"),
  );
  assert.ok(addChannel.includes("Verify ownership (optional)"));
  assert.ok(addChannel.includes("optional\n"));
});
const badge = block(
  components,
  "export function ChannelVerificationBadge",
  "/** Account-level reminder:",
);
test("Badges: Verified / Not verified / Blocked / Verify to record", () => {
  for (const text of ["Blocked", "Verified", "Not verified", "Verify to record", "Verify by"]) {
    assert.ok(badge.includes(text), text);
  }
  assert.ok(badge.includes("bg-destructive/10 text-destructive"), "Blocked uses the danger tone");
  assert.ok(badge.includes('bg-surface-2 text-muted-foreground", className)}>Not verified'));
});
const controls = block(
  components,
  "export function useChannelControls",
  "export function ExpiryText",
);
test("Blocked: resume is refused with the blocked text", () => {
  assert.ok(controls.includes("const blocked = Boolean(channel.blocked);"));
  assert.ok(controls.includes("description: CHANNEL_BLOCKED_TEXT"));
  assert.ok(read(components).includes("disabled={c.pending || c.blocked}"));
  assert.ok(read(components).includes("disabled={controls.blocked}"));
});
const pages = read("src/components/app-pages.tsx");
const detail = block(
  "src/components/app-pages.tsx",
  "function ChannelDetail({",
  "function RecordingHeader()",
);
test("Channel detail: blocked banner and disabled record/resume controls", () => {
  assert.ok(detail.includes("description={CHANNEL_BLOCKED_TEXT}"));
  assert.ok(detail.includes("disabled={pending || blocked}"));
  assert.ok(detail.includes("disabled={pending || !canAutoRecord || blocked}"));
  assert.ok(detail.includes("<DropdownMenuItem disabled={blocked}"));
  assert.ok(detail.includes("<ChannelVerificationBadge channel={channel}"));
});
test("Channel detail: legacy prompt and optional verify", () => {
  assert.ok(detail.includes("needsLegacyAttestation(channel) && <ChannelAttestationPrompt"));
  assert.ok(detail.includes("handle={channel.handle} optional"));
  assert.ok(pages.includes("ChannelAttestationPrompt,"));
});
const verification = read("src/components/app/channel-verification.tsx");
test("Legacy prompt: PATCH owner_attested=true, a prompt only", () => {
  assert.ok(verification.includes("input: { owner_attested: true }"));
  assert.ok(verification.includes("{LEGACY_ATTESTATION_PROMPT}"));
  assert.ok(verification.includes("{OWNERSHIP_STATEMENT}"));
  assert.ok(verification.includes("disabled={!ticked || update.isPending}"));
});
test("Verify card: auto re-check on return to the tab; retry_later is 'Still checking…'", () => {
  assert.ok(verification.includes('addEventListener("visibilitychange"'));
  assert.ok(verification.includes('addEventListener("focus"'));
  assert.ok(verification.includes("autoCheckDelay({"));
  assert.ok(verification.includes("retryAfterSeconds: check.data?.retry_after_seconds"));
  assert.ok(verification.includes("Still checking…"));
  assert.ok(!verification.includes("SaveStream records only channels you’ve verified"));
});
test("Errors: CHANNEL_BLOCKED / CHANNEL_NOT_VERIFIED / OWNERSHIP_ATTESTATION_REQUIRED mapped", () => {
  const mutations = read("src/hooks/use-channel-mutations.ts");
  assert.ok(mutations.includes('error.code === "CHANNEL_BLOCKED") return CHANNEL_BLOCKED_TEXT'));
  assert.ok(mutations.includes('error.code === "CHANNEL_NOT_VERIFIED"'));
  assert.ok(mutations.includes('error.code === "OWNERSHIP_ATTESTATION_REQUIRED"'));
  const recordings = read("src/hooks/use-recording-mutations.ts");
  assert.ok(recordings.includes('error.code === "CHANNEL_BLOCKED") return CHANNEL_BLOCKED_TEXT'));
});
test("Types: watch fields from the API", () => {
  const types = read("src/api/types.ts");
  assert.ok(types.includes('ownership_basis?: "web_attested" | "web_attested_legacy" | null;'));
  assert.ok(types.includes("blocked?: boolean;"));
  assert.ok(types.includes("owner_attested?: true;"));
  const mapper = read("src/repositories/mappers/channel.ts");
  assert.ok(mapper.includes("blocked: watch.blocked ?? false"));
  assert.ok(mapper.includes("ownershipBasis: watch.ownership_basis ?? null"));
});

// --- Admin -----------------------------------------------------------------
test("Admin API: per-account channel blocks with step-up", () => {
  const api = read("src/repositories/admin-api.ts");
  assert.ok(api.includes("`/v1/admin/watches/${encodeURIComponent(watchId)}/block`"));
  assert.ok(api.includes("`/v1/admin/channel-blocks/${encodeURIComponent(blockId)}/unblock`"));
  assert.ok(api.includes("`/v1/admin/channel-blocks?${query.toString()}`"));
  const blockApi = block(
    "src/repositories/admin-api.ts",
    "blockChannelForAccount(",
    "suspiciousAccounts(",
  );
  assert.equal(blockApi.split("headers: stepUpHeaders(stepUpToken)").length - 1, 2);
});
test("Admin UI: block from user channels and complaints; blocks list with Unblock", () => {
  const dialog = read("src/components/admin/channel-account-blocks.tsx");
  assert.ok(dialog.includes("adminFoundationApi.stepUp(password, totp)"));
  assert.ok(dialog.includes("reason.trim().length >= 3"));
  assert.ok(dialog.includes("Complaint ID"));
  assert.ok(dialog.includes("Unblock"));
  const users = read("src/components/admin/user-support.tsx");
  assert.ok(users.includes("Block for this account"));
  assert.ok(users.includes("<ChannelAccountBlocksTable"));
  assert.ok(users.includes("listChannelAccountBlocks({ activeOnly: true, userId })"));
  const safety = read("src/components/admin/safety-d8.tsx");
  assert.ok(safety.includes('value="channel-blocks"'));
  assert.ok(safety.includes("complaintId: complaint.id"));
});

// --- Copy rule: never claim every channel is verified ----------------------
test("No copy claims every channel is verified", () => {
  const banned = [
    /verified channels only/i,
    /only (records )?channels you(’|')ve verified/i,
    /every channel (on SaveStream )?is verified/i,
    /SaveStream verifies (all|every)/i,
    /only verified channels/i,
  ];
  const files = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(path.join(root, dir), { withFileTypes: true })) {
      const rel = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(rel);
      else if (/\.(tsx?|md|txt)$/.test(entry.name)) files.push(rel);
    }
  };
  walk("src");
  walk("public");
  for (const file of files) {
    const source = read(file);
    for (const pattern of banned) assert.ok(!pattern.test(source), `${file}: ${pattern}`);
  }
});

if (failures.length) {
  console.error(
    `\n${failures.length} channel ownership check(s) failed:\n- ${failures.join("\n- ")}`,
  );
  process.exit(1);
}
console.log("\nChannel ownership audit passed.");
