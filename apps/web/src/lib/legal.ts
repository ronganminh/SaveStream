/**
 * Revision dates of the published Terms of Use and Privacy Policy. Must match
 * the backend (app/application/identity/legal.py) and the "Last updated"
 * date on /terms and /privacy; sign-up sends them as consent evidence.
 */
export const TERMS_VERSION = "2026-10-14";
export const PRIVACY_VERSION = "2026-10-14";
export const LEGAL_REVISION_LABEL = "October 14, 2026";
/** "Last updated" date of /acceptable-use (backend CURRENT_AUP_VERSION). */
export const AUP_VERSION = "2026-10-05";

export type LegalConsent = {
  age_confirmed: true;
  terms_version: string;
  privacy_version: string;
  aup_accepted: true;
  aup_version: string;
};

/** Sent only after both sign-up checkboxes (18+/Terms/Privacy and Acceptable Use) are ticked. */
export function currentLegalConsent(): LegalConsent {
  return {
    age_confirmed: true,
    terms_version: TERMS_VERSION,
    privacy_version: PRIVACY_VERSION,
    aup_accepted: true,
    aup_version: AUP_VERSION,
  };
}

export type SocialProviderName = "google" | "apple";

export type SocialSignUpGate =
  | { ok: true }
  | {
      ok: false;
      /** Shown right under the Google/Apple buttons. */
      message: string;
      agreeMissing: boolean;
      aupMissing: boolean;
      /** The first unticked checkbox, to scroll to and focus. */
      focus: "agree" | "aup";
    };

/**
 * Sign-up with Google/Apple creates an account, so both consent checkboxes
 * must be ticked first. Before this, an unticked click only marked the
 * checkboxes far below the buttons, which looked like a dead button.
 */
export function socialSignUpGate(
  provider: SocialProviderName,
  agreed: boolean,
  aupAgreed: boolean,
): SocialSignUpGate {
  if (agreed && aupAgreed) return { ok: true };
  const name = provider === "google" ? "Google" : "Apple";
  return {
    ok: false,
    message: `Please agree to the Terms of Use, Privacy Policy and Acceptable Use Policy below to continue with ${name}.`,
    agreeMissing: !agreed,
    aupMissing: !aupAgreed,
    focus: agreed ? "aup" : "agree",
  };
}
