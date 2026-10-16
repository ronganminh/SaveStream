import type { PublicPricingResponse } from "@/api/types";
import { guides } from "@/lib/guides-content";
import { PUBLIC_SITE_URL } from "@/lib/route-metadata";

/**
 * /llms.txt (https://llmstxt.org): a short Markdown summary of SaveStream for
 * AI assistants. Prices and limits come from the live /v1/public/pricing
 * response so they never go stale; without it the numbers are left out.
 */
export function buildLlmsTxt(pricing: PublicPricingResponse | null): string {
  const site = PUBLIC_SITE_URL;
  const money = (minor: number, currency: string) =>
    new Intl.NumberFormat("en-US", { style: "currency", currency }).format(minor / 100);
  const rate = pricing?.recording_rate;
  const minutesPerCredit =
    rate && rate.credits_per_unit > 0 ? rate.unit_seconds / 60 / rate.credits_per_unit : null;

  const facts: string[] = [
    "- Cloud recording: SaveStream checks each added channel about every 30 seconds and, with Auto-record on, records the LIVE on its servers. No phone or computer needs to stay on.",
    "- Free trial: new accounts can use Auto-record on their free trial minutes after verifying their email (one recording at a time); when the minutes are used up, they buy a credit pack to keep recording.",
    "- Recordings keep TikTok's vertical format and download as MP4 files; downloading is free.",
    "- Only channels the user owns, manages, or has clear permission from the creator to record may be added (Acceptable Use Policy). Users must be 18+.",
  ];
  if (pricing) {
    if (minutesPerCredit !== null) {
      facts.push(
        `- Billing: credits pay for recording time (${minutesPerCredit === 1 ? "1 credit per minute" : `1 credit per ${minutesPerCredit} minutes`}); checking offline channels is free; failed or missed recordings are not charged.`,
      );
    }
    if (pricing.packages.length) {
      const packs = pricing.packages
        .map(
          (pack) =>
            `${pack.name} ${money(pack.price.amount_minor, pack.price.currency)} for ${pack.credits.toLocaleString("en-US")} credits`,
        )
        .join("; ");
      facts.push(
        `- Credit packs (one-time payments via PayPal, no subscription, credits never expire): ${packs}.`,
      );
    }
    if (pricing.signup_credits) {
      facts.push(
        `- New accounts receive ${pricing.signup_credits} free trial credits${
          minutesPerCredit !== null
            ? ` (${Math.floor(pricing.signup_credits * minutesPerCredit)} minutes of recording)`
            : ""
        } once, after verifying their email. They record for real with Auto-record, one recording at a time; when they are used up the recording stops, is saved, and the user buys a pack to keep recording.`,
      );
    }
    if (pricing.free_max_channels_per_user && pricing.max_channels_per_user) {
      facts.push(
        `- Channel limits: up to ${pricing.free_max_channels_per_user} channels on free accounts, up to ${pricing.max_channels_per_user} after a purchase; up to ${pricing.max_concurrent_recordings_per_user} recordings at the same time.`,
      );
    }
    if (pricing.recording_retention_days) {
      facts.push(
        `- Recordings are stored for ${pricing.recording_retention_days} days on accounts that have bought credits${
          pricing.trial_recording_retention_days
            ? ` (${pricing.trial_recording_retention_days} days on trial-only accounts)`
            : ""
        }, then deleted.`,
      );
    }
  } else {
    facts.push(`- Current prices and limits: ${site}/pricing`);
  }

  return [
    "# SaveStream",
    "",
    "> SaveStream is a cloud TikTok LIVE recorder for creators, LIVE sellers and the teams that manage their channels. It watches the TikTok channels a user adds and records their LIVEs automatically in the cloud, then lets the user watch or download them.",
    "",
    "## Key facts",
    "",
    ...facts,
    "",
    "## Main pages",
    "",
    `- [Home](${site}/): product overview`,
    `- [TikTok LIVE recorder](${site}/tiktok-live-recorder): how automatic cloud recording works`,
    `- [Pricing](${site}/pricing): credit packs and limits`,
    `- [Help center](${site}/help): account, channels, recordings and billing help`,
    `- [Acceptable Use Policy](${site}/acceptable-use): which channels may be recorded`,
    `- [Terms of Use](${site}/terms)`,
    `- [Privacy Policy](${site}/privacy)`,
    `- [Contact](${site}/contact)`,
    "",
    "## Guides",
    "",
    ...guides.map((item) => `- [${item.title}](${site}/guides/${item.slug}): ${item.summary}`),
    "",
  ].join("\n");
}
