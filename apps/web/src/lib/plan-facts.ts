import type { PublicPricingResponse } from "@/api/types";
import { pluralize } from "@/lib/formatters";

// Copy built from the Admin runtime settings that /v1/public/pricing returns
// (signup credits, channel limits, retention). Never hard-code these numbers:
// when the data is not loaded yet, the sentences fall back to wording without
// a number.

type Pricing = PublicPricingResponse | null | undefined;

export function retentionSentence(pricing: Pricing): string {
  const paid = pricing?.recording_retention_days;
  const trial = pricing?.trial_recording_retention_days;
  if (paid && trial && trial !== paid) {
    return `Finished recordings are stored for ${pluralize(paid, "day")} after you buy credits, or ${pluralize(trial, "day")} on the free trial`;
  }
  if (paid) return `Finished recordings are stored for ${pluralize(paid, "day")}`;
  return "Finished recordings are stored for a limited time";
}

export function retentionFeature(pricing: Pricing): string {
  const paid = pricing?.recording_retention_days;
  return paid ? `Stored for up to ${pluralize(paid, "day")}` : "Automatic storage expiry";
}

export function freeWebSentence(pricing: Pricing, channelLimit?: number | null): string {
  const credits = pricing?.signup_credits ?? 0;
  const channels = channelLimit ?? pricing?.free_max_channels_per_user ?? null;
  const parts = [
    credits > 0 ? `${credits} trial credits` : "free trial credits",
    channels ? `up to ${pluralize(channels, "monitored channel")}` : null,
  ].filter(Boolean);
  return `Free web accounts get ${parts.join(" and ")}.`;
}

type Pack = PublicPricingResponse["packages"][number];

/** Recording hours a pack buys, from the live pricing rule (null if unknown). */
export function packHours(pack: Pack): number | null {
  return pack.recording_minutes && pack.recording_minutes > 0 ? pack.recording_minutes / 60 : null;
}

/** Price per recorded hour in the pack's currency, or null. */
export function packPricePerHour(pack: Pack): number | null {
  const hours = packHours(pack);
  return hours ? pack.price.amount_minor / 100 / hours : null;
}

/**
 * Smallest pack that covers about a month at `hoursPerWeek`; the largest
 * pack when none does. Index into `packs`, or -1 without hour data.
 */
export function recommendPack(packs: readonly Pack[], hoursPerWeek: number): number {
  const monthly = hoursPerWeek * 4.33;
  let best = -1;
  packs.forEach((pack, index) => {
    const hours = packHours(pack);
    if (hours === null) return;
    const bestHours = best >= 0 ? packHours(packs[best]!)! : null;
    if (hours >= monthly && (bestHours === null || bestHours < monthly || hours < bestHours)) {
      best = index;
    } else if (bestHours === null || (bestHours < monthly && hours > bestHours)) {
      best = index;
    }
  });
  return best;
}
