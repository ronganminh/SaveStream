export const analyticsEventNames = [
  "landing_cta_clicked",
  "pricing_viewed",
  "plan_selected",
  "signup_started",
  "signup_completed",
  "add_channel_opened",
  "channel_lookup_started",
  "channel_added",
  "monitoring_toggled",
  "recording_opened",
  "sample_recording_played",
  "download_clicked",
  "quota_warning_viewed",
  "support_opened",
] as const;

export type AnalyticsEventName = (typeof analyticsEventNames)[number];

export type AnalyticsPropertyMap = {
  landing_cta_clicked: { location: "hero" | "pricing" | "footer"; destination: "signup" | "pricing" };
  pricing_viewed: { source: "route" };
  plan_selected: { plan: "free" | "pro"; source: "landing" | "pricing" };
  signup_started: { method: "email" | "google" };
  signup_completed: { method: "email" };
  add_channel_opened: { source: "dialog" | "onboarding" };
  channel_lookup_started: { input_kind: "username" | "profile_url" };
  channel_added: { source: "dialog" | "onboarding" };
  monitoring_toggled: { enabled: boolean; source: "list" | "detail" };
  recording_opened: { source: "overview" | "list" | "grid" | "detail" };
  sample_recording_played: { sample_id: string };
  download_clicked: { kind: "recording" | "partial"; result: "eligible" | "quota_insufficient" | "unavailable" };
  quota_warning_viewed: { kind: "recording_hours" | "download" | "channels" };
  support_opened: { source: "help" };
};

export type AnalyticsMode = "demo" | "production";

export type AnalyticsEnvelope<Name extends AnalyticsEventName = AnalyticsEventName> = {
  event: Name;
  mode: AnalyticsMode;
  demo: boolean;
  timestamp: string;
  properties: AnalyticsPropertyMap[Name];
};

const forbiddenPropertyKey = /(email|full.?name|username|channel.?url|video.?title|support.?message|message.?body)/i;

export function buildAnalyticsEnvelope<Name extends AnalyticsEventName>(
  mode: AnalyticsMode,
  event: Name,
  properties: AnalyticsPropertyMap[Name],
): AnalyticsEnvelope<Name> {
  for (const key of Object.keys(properties)) {
    if (forbiddenPropertyKey.test(key)) {
      throw new Error(`Unsafe analytics property: ${key}`);
    }
  }
  return {
    event,
    mode,
    demo: mode === "demo",
    timestamp: new Date().toISOString(),
    properties,
  };
}
