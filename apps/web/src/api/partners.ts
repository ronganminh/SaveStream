import { apiClient } from "@/api/client";

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
