// Channel ownership on the website: the user confirms (a required checkbox)
// that they own the channel or have the creator's permission to record it.
// Verifying with a code in the TikTok bio is optional on the web unless the
// API says otherwise (`verification_required`), so everything here is driven
// by the watch fields, never by a client flag.
//
// No imports on purpose: scripts/channel-ownership-audit.mjs loads this file
// directly with Node to test the rules below.

/** The checkbox label on Add channel (the server stores this wording's version). */
export const OWNERSHIP_STATEMENT =
  "I own this channel or have the creator's permission to record it.";

/** Shown when the box is not ticked (API: OWNERSHIP_ATTESTATION_REQUIRED). */
export const OWNERSHIP_REQUIRED_TEXT =
  "Tick the box to confirm you own this channel or have the creator's permission to record it.";

/** Gentle prompt for channels added before the box was required. */
export const LEGACY_ATTESTATION_PROMPT =
  "Please confirm you own this channel or have the creator's permission to record it.";

/** A channel ops stopped for this account (API: `blocked`, CHANNEL_BLOCKED). */
export const CHANNEL_BLOCKED_TEXT =
  "Recording stopped for this channel on your account after a report. Contact support if you think this is a mistake.";

/** API: CHANNEL_NOT_VERIFIED. */
export const CHANNEL_NOT_VERIFIED_TEXT =
  "Verify this channel to record it: open the channel and add the short code to your TikTok bio.";

export type OwnershipFields = {
  ownerVerifiedAt?: string | null | undefined;
  verificationRequired?: boolean | undefined;
  verificationDueAt?: string | null | undefined;
  ownershipBasis?: "web_attested" | "web_attested_legacy" | null | undefined;
  blocked?: boolean | undefined;
};

export type OwnershipBadgeKind =
  "blocked" | "verified" | "verify_to_record" | "verify_by" | "not_verified";

/** Which ownership badge a channel shows (list, cards and detail). */
export function ownershipBadgeKind(channel: OwnershipFields): OwnershipBadgeKind {
  if (channel.blocked) return "blocked";
  if (channel.ownerVerifiedAt) return "verified";
  if (channel.verificationRequired) return "verify_to_record";
  // Grace deadline for channels added before verification existed; web
  // channels the user confirmed ownership of don't need it.
  if (!channel.ownershipBasis && channel.verificationDueAt) return "verify_by";
  return "not_verified";
}

/** The bio-code step is required before this channel can record. */
export function verificationIsRequired(channel: OwnershipFields): boolean {
  return !channel.blocked && !channel.ownerVerifiedAt && Boolean(channel.verificationRequired);
}

/** Account-level "verify your channels" reminder applies to this channel. */
export function needsVerificationReminder(channel: OwnershipFields): boolean {
  const kind = ownershipBadgeKind(channel);
  return kind === "verify_to_record" || kind === "verify_by";
}

/** Ask the user to tick the ownership box again (a prompt only; recording
 * is not blocked by it). */
export function needsLegacyAttestation(channel: OwnershipFields): boolean {
  return (
    !channel.blocked && !channel.ownerVerifiedAt && channel.ownershipBasis === "web_attested_legacy"
  );
}

// Auto re-check of the bio code while the verify steps are open: after the
// user comes back to the tab, check at most every 15 s for at most 5 min,
// waiting longer when the server asks to, and keep a few checks for the user.
export const AUTO_CHECK_MIN_INTERVAL_MS = 15_000;
export const AUTO_CHECK_WINDOW_MS = 5 * 60_000;
export const AUTO_CHECK_RESERVED_CHECKS = 3;

export type AutoCheckInput = {
  now: number;
  /** When the last check (manual or automatic) was sent; null if none yet. */
  lastCheckAt: number | null;
  /** The server's `retry_after_seconds` hint from the last answer. */
  retryAfterSeconds?: number | null | undefined;
  /** End of the auto-check window; null when auto-checking is off. */
  windowEndsAt: number | null;
  /** The server's `checks_left`; null when unknown. */
  checksLeft?: number | null | undefined;
};

/** Milliseconds until the next automatic check, or null for "don't". */
export function autoCheckDelay({
  now,
  lastCheckAt,
  retryAfterSeconds,
  windowEndsAt,
  checksLeft,
}: AutoCheckInput): number | null {
  if (windowEndsAt === null || now >= windowEndsAt) return null;
  if (typeof checksLeft === "number" && checksLeft <= AUTO_CHECK_RESERVED_CHECKS) return null;
  const earliest =
    lastCheckAt === null
      ? now
      : lastCheckAt + Math.max(AUTO_CHECK_MIN_INTERVAL_MS, (retryAfterSeconds ?? 0) * 1000);
  if (earliest >= windowEndsAt) return null;
  return Math.max(0, earliest - now);
}
