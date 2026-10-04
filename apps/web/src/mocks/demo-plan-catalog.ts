export type PlanId = "free" | "pro";

export type PlanQuota = number | null;

export type PlanCatalogEntry = {
  id: PlanId;
  name: "Free" | "Pro";
  priceMonthlyUsd: number;
  /** Annual pricing is intentionally disabled until the product owner approves a real price. */
  priceYearlyUsd: null;
  quotas: {
    recordingMinutes: number;
    recordingHours: number | null;
    savedChannels: PlanQuota;
    monitoredChannels: number;
    simultaneousRecordings: number;
    downloadGb: PlanQuota;
    retentionDays: number;
  };
  features: string[];
};

export const planCatalog: Record<PlanId, PlanCatalogEntry> = {
  free: {
    id: "free",
    name: "Free",
    priceMonthlyUsd: 0,
    priceYearlyUsd: null,
    quotas: {
      recordingMinutes: 10,
      recordingHours: 10 / 60,
      savedChannels: null,
      monitoredChannels: 3,
      simultaneousRecordings: 1,
      downloadGb: null,
      retentionDays: 7,
    },
    features: [
      "10 trial cloud credits after email verification",
      "Saved channels: not specified",
      "3 monitored channels",
      "Manual cloud recording while trial credits remain",
      "Download bandwidth: not specified",
      "7-day retention",
    ],
  },
  pro: {
    id: "pro",
    name: "Pro",
    priceMonthlyUsd: 0,
    priceYearlyUsd: null,
    quotas: {
      recordingMinutes: 3000,
      recordingHours: 50,
      savedChannels: null,
      monitoredChannels: 20,
      simultaneousRecordings: 3,
      downloadGb: 100,
      retentionDays: 30,
    },
    features: [
      "Cloud hours come from one-time purchases",
      "Saved channels: not specified",
      "20 monitored channels",
      "3 simultaneous cloud recordings",
      "Credits never expire",
      "30-day retention",
    ],
  },
};

export const planList = [planCatalog.free, planCatalog.pro] as const;

export const planLimitDefinitions = [
  {
    key: "savedChannels",
    label: "Saved channels",
    description: "Profiles stored in your SaveStream workspace.",
  },
  {
    key: "monitoredChannels",
    label: "Monitored channels",
    description: "Channels that SaveStream is actively checking for live status.",
  },
  {
    key: "simultaneousRecordings",
    label: "Simultaneous recordings",
    description: "Livestreams that can be recorded at the same time.",
  },
] as const;

export const planMediaFootnote =
  "Video size and download usage vary with stream bitrate, resolution, and duration.";
