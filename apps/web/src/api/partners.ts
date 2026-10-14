import { apiClient } from "@/api/client";
import { apiBaseUrl } from "@/lib/app-config";

/** Niches offered on /partners/apply; the backend accepts exactly these. */
export const PARTNER_NICHES = [
  "Fitness",
  "Gaming",
  "Music",
  "Beauty & fashion",
  "Food & cooking",
  "Education",
  "Shopping / live selling",
  "Other",
] as const;

/** Confirmation texts as approved; the backend stores the same strings with each application. */
export const PARTNER_CONSENT_OWNS_ACCOUNT = "I own or manage this TikTok account.";
export const PARTNER_CONSENT_DISPLAY =
  "I consent to SaveStream displaying my name, handle, image and clips on its website (revocable anytime by emailing support).";

export type PartnerApplicationRequest = {
  name: string;
  email: string;
  tiktok_handle: string;
  other_channel_url: string | null;
  niche: string;
  story: string;
  /** PNG or JPG as a data URL, 5 MB or smaller. */
  photo: string | null;
  consent_owns_account: boolean;
  consent_display: boolean;
  turnstile_token?: string | null;
  /** Honeypot; must stay empty. */
  website?: string;
};

export type PartnerApplicationReceipt = { reference: string };

/** POST /v1/public/partner-applications — anonymous; reviewed in Admin → Partners. */
export function submitPartnerApplication(payload: PartnerApplicationRequest) {
  return apiClient.post<PartnerApplicationReceipt>("/v1/public/partner-applications", {
    json: payload,
  });
}

/** A published creator story (approved, published, consent not withdrawn). */
export type PartnerStory = {
  id: string;
  name: string;
  tiktok_handle: string;
  niche: string;
  story: string;
  has_photo: boolean;
  published_at: string | null;
};

/** GET /v1/public/partner-stories — empty when no story is published. */
export function listPartnerStories() {
  return apiClient.get<{ items: PartnerStory[] }>("/v1/public/partner-stories", {
    skipAuth: true,
  });
}

/** Public photo URL; served only while the story is published and consented. */
export function partnerStoryPhotoUrl(storyId: string) {
  return `${apiBaseUrl.replace(/\/$/, "")}/v1/public/partner-stories/${encodeURIComponent(storyId)}/photo`;
}
