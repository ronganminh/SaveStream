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
