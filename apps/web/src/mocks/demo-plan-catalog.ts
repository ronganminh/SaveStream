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
      monitoredChannels: 1,
      simultaneousRecordings: 1,
      downloadGb: null,
      retentionDays: 3,
    },
    features: [
      "10 minutes recording / month",
      "Saved channels: not specified",
      "1 monitored channel",
      "1 simultaneous recording",
      "Download bandwidth: not specified",
      "3-day retention",
    ],
  },
  pro: {
    id: "pro",
    name: "Pro",
    priceMonthlyUsd: 9.99,
    priceYearlyUsd: null,
    quotas: {
      recordingMinutes: 3000,
      recordingHours: 50,
      savedChannels: null,
      monitoredChannels: 5,
      simultaneousRecordings: 2,
      downloadGb: 100,
      retentionDays: 30,
    },
    features: [
      "50 recording hours / month",
      "Saved channels: not specified",
      "5 monitored channels",
      "2 simultaneous recordings",
      "100 GB downloads / month",
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
