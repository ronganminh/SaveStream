import type { EntitlementResponse } from "@/api/types";

// Who may switch Auto-record on (backend EntitlementSnapshot.can_auto_record):
// accounts with purchased credit, and new accounts spending their free trial
// minutes once their email is verified. One recording at a time on the trial.

export type AutoRecordReason =
  "ok" | "loading" | "verify_email" | "trial_used_up" | "out_of_credits";

export type AutoRecordAccess = {
  allowed: boolean;
  /** Recording on free trial minutes (not purchased yet). */
  trial: boolean;
  reason: AutoRecordReason;
};

export function autoRecordAccess(
  entitlement: EntitlementResponse | null | undefined,
  demo = false,
): AutoRecordAccess {
  if (demo) return { allowed: true, trial: false, reason: "ok" };
  if (!entitlement) return { allowed: false, trial: false, reason: "loading" };
  const allowed = entitlement.can_auto_record ?? entitlement.plan === "pro";
  const trial = allowed && !entitlement.has_purchased;
  if (allowed) return { allowed, trial, reason: "ok" };
  if (!entitlement.has_purchased && entitlement.email_verified === false) {
    return { allowed, trial, reason: "verify_email" };
  }
  return {
    allowed,
    trial,
    reason: entitlement.has_purchased ? "out_of_credits" : "trial_used_up",
  };
}

export const FREE_MINUTES_USED_UP = "Your free minutes are used up — buy a pack to keep recording.";

/** Why Auto-record can't be switched on, in one sentence. */
export function autoRecordBlockedText(access: AutoRecordAccess): string {
  switch (access.reason) {
    case "verify_email":
      return "Verify your email to record with your free minutes.";
    case "trial_used_up":
      return FREE_MINUTES_USED_UP;
    case "out_of_credits":
      return "You’re out of credits — buy a pack to keep recording.";
    case "loading":
      return "Checking your account…";
    default:
      return "";
  }
}

/** "Uses your 10 free trial minutes first, then buy a pack." */
export function trialRecordingText(trialLabel: string | null): string {
  return trialLabel
    ? `Records with your ${trialLabel}, one LIVE at a time; then buy a pack to keep recording.`
    : "Records with your free trial minutes, one LIVE at a time; then buy a pack to keep recording.";
}

/** For free accounts: what Auto-record does for them right now. */
export function freeAutoRecordSentence(
  access: AutoRecordAccess,
  trialLabel: string | null,
): string {
  if (access.allowed || access.reason === "loading") {
    return trialLabel
      ? `Turn on Auto-record to try it with your ${trialLabel}, then buy a pack to keep recording.`
      : "Turn on Auto-record to try it with your free trial minutes, then buy a pack to keep recording.";
  }
  return autoRecordBlockedText(access);
}
