import { apiClient } from "@/api/client";

export type PublicReportRequest =
  | {
      kind: "copyright";
      email: string;
      name: string;
      relationship: "rights_holder" | "agent" | "employee";
      work_description: string;
      locations: string;
      good_faith: boolean;
      accurate_and_authorized: boolean;
      signature: string;
      turnstile_token?: string | null;
    }
  | {
      kind: "abuse";
      email: string;
      target: string;
      reporter_role: "self" | "other" | "on_behalf";
      description: string;
      turnstile_token?: string | null;
    };

/** Sent with every report; `website` is the honeypot and must stay empty. */
export type PublicReportExtras = { turnstile_token?: string | null; website?: string };

export type PublicReportResponse = { reference: string; kind: "copyright" | "abuse" };

/** POST /v1/public/reports — anonymous; becomes a case in Admin → Safety. */
export function submitPublicReport(payload: PublicReportRequest & PublicReportExtras) {
  return apiClient.post<PublicReportResponse>("/v1/public/reports", { json: payload });
}
