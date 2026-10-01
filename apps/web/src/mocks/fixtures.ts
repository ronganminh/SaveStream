/**
 * Prototype mock data. Every export here is a UI-facing model that a real API
 * can replace later. Keep component code free of hardcoded records.
 */

// ---------- Status enums ----------
export type ChannelStatus = "Recording" | "Waiting" | "Offline" | "Paused" | "Error";
export type RecordingStatus = "Recording" | "Processing" | "Ready" | "Error";
/** Union used by the shared StatusBadge. */
export type Status = ChannelStatus | RecordingStatus;

// ---------- User ----------
import { planCatalog, planList, type PlanId } from "@/lib/plan-catalog";
export type { PlanId } from "@/lib/plan-catalog";
export type User = {
  id: string;
  name: string;
  email: string;
  plan: "Free" | "Pro";
  planId: PlanId;
  initials: string;
  emailVerified: boolean;
  loginMethods: ("email" | "google")[];
};
export const user: User = {
  id: "usr_01",
  name: "Alex Nguyen",
  email: "alex@savestream.app",
  plan: "Pro",
  planId: "pro",
  initials: "AN",
  emailVerified: true,
  loginMethods: ["email"],
};

// ---------- Channels ----------
export type Channel = {
  id: string;
  name: string;
  handle: string;
  initials: string;
  platform: "tiktok";
  status: ChannelStatus;
  monitoring: boolean;
  live: string;
  checked: string;
  recordings: number;
  recordedHours: string;
  storage: string;
  tone: string;
};
export const channels: Channel[] = [
  {
    id: "lina",
    name: "Lina Studio",
    handle: "@linastudio",
    initials: "LS",
    platform: "tiktok",
    status: "Recording",
    monitoring: true,
    live: "Live now · 01:42:18",
    checked: "Now",
    recordings: 11,
    recordedHours: "21.6 h",
    storage: "12.8 GB",
    tone: "from-avatar-one to-avatar-one-end",
  },
  {
    id: "mike",
    name: "Mike Fitness",
    handle: "@mikefitness",
    initials: "MF",
    platform: "tiktok",
    status: "Waiting",
    monitoring: true,
    live: "Yesterday, 20:15",
    checked: "20s ago",
    recordings: 4,
    recordedHours: "5.2 h",
    storage: "4.1 GB",
    tone: "from-avatar-two to-avatar-two-end",
  },
  {
    id: "nora",
    name: "Nora Shop",
    handle: "@norashop",
    initials: "NS",
    platform: "tiktok",
    status: "Offline",
    monitoring: true,
    live: "Sep 24, 11:04",
    checked: "32s ago",
    recordings: 3,
    recordedHours: "2.4 h",
    storage: "1.7 GB",
    tone: "from-avatar-three to-avatar-three-end",
  },
];
/** Mock handles the Add channel dialog resolves to specific states. */
export const channelLookupExamples = [
  { input: "@creatorstudio", result: "Found" },
  { input: "@linastudio", result: "Already monitored" },
  { input: "@notfound", result: "Not found" },
  { input: "@unavailable", result: "TikTok unavailable" },
  { input: "@limit", result: "Plan limit" },
];

// ---------- Recordings ----------
export type Recording = {
  id: string;
  channelId: string;
  handle: string;
  title: string;
  date: string;
  time: string;
  duration: string;
  size: string;
  sizeGb: number;
  resolution: string;
  expires: string;
  expiresDays: number | null;
  expireTone?: "warning" | "critical";
  status: RecordingStatus;
  color: string;
  error?: string;
  partialDuration?: string;
};
export const recordings: Recording[] = [
  {
    id: "lina-sep27",
    channelId: "lina",
    handle: "@linastudio",
    title: "Sep 27 livestream",
    date: "Sep 27, 2026",
    time: "13:22",
    duration: "2h 14m",
    size: "4.8 GB",
    sizeGb: 4.8,
    resolution: "1080p",
    expires: "29 days",
    expiresDays: 29,
    status: "Ready",
    color: "bg-thumbnail-one",
  },
  {
    id: "nora-processing",
    channelId: "nora",
    handle: "@norashop",
    title: "Sep 27 product live",
    date: "Sep 27, 2026",
    time: "16:48",
    duration: "48m",
    size: "1.7 GB",
    sizeGb: 1.7,
    resolution: "1080p",
    expires: "—",
    expiresDays: null,
    status: "Processing",
    color: "bg-thumbnail-four",
  },
  {
    id: "mike-sep26",
    channelId: "mike",
    handle: "@mikefitness",
    title: "Sep 26 livestream",
    date: "Sep 26, 2026",
    time: "20:15",
    duration: "1h 08m",
    size: "2.3 GB",
    sizeGb: 2.3,
    resolution: "720p",
    expires: "28 days",
    expiresDays: 28,
    status: "Ready",
    color: "bg-thumbnail-two",
  },
  {
    id: "nora-failed",
    channelId: "nora",
    handle: "@norashop",
    title: "Sep 25 livestream",
    date: "Sep 25, 2026",
    time: "09:41",
    duration: "47m",
    size: "1.6 GB",
    sizeGb: 1.6,
    resolution: "1080p",
    expires: "27 days",
    expiresDays: 27,
    status: "Error",
    color: "bg-thumbnail-three",
    error: "Stream disconnected",
    partialDuration: "47 minutes",
  },
  {
    id: "lina-sep24",
    channelId: "lina",
    handle: "@linastudio",
    title: "Sep 24 livestream",
    date: "Sep 24, 2026",
    time: "11:04",
    duration: "3h 02m",
    size: "6.1 GB",
    sizeGb: 6.1,
    resolution: "1080p",
    expires: "3 days",
    expiresDays: 3,
    expireTone: "warning",
    status: "Ready",
    color: "bg-thumbnail-three",
  },
  {
    id: "mike-aug29",
    channelId: "mike",
    handle: "@mikefitness",
    title: "Aug 29 livestream",
    date: "Aug 29, 2026",
    time: "19:30",
    duration: "1h 22m",
    size: "2.9 GB",
    sizeGb: 2.9,
    resolution: "720p",
    expires: "Tomorrow",
    expiresDays: 1,
    expireTone: "critical",
    status: "Ready",
    color: "bg-thumbnail-two",
  },
];

// ---------- Notifications ----------
export type NotificationType =
  "recording_started" | "recording_ready" | "recording_failed" | "quota_warning";
export type NotificationLink =
  { to: "/recordings/$id" | "/channels/$id"; params: { id: string } } | { to: "/usage" };
export type Notification = {
  id: string;
  type: NotificationType;
  title: string;
  body: string;
  time: string;
  status: Status;
  read: boolean;
  link: NotificationLink;
};
export const notifications: Notification[] = [
  {
    id: "n1",
    type: "recording_started",
    title: "Recording started",
    body: "@linastudio is live and recording has started.",
    time: "1h ago",
    status: "Recording",
    read: false,
    link: { to: "/channels/$id", params: { id: "lina" } },
  },
  {
    id: "n2",
    type: "recording_ready",
    title: "Recording ready",
    body: "Your 2h 14m livestream recording is ready to watch.",
    time: "Yesterday",
    status: "Ready",
    read: false,
    link: { to: "/recordings/$id", params: { id: "lina-sep27" } },
  },
  {
    id: "n3",
    type: "recording_failed",
    title: "Recording failed",
    body: "@norashop’s recording stopped after the stream disconnected. 47 minutes were saved.",
    time: "2d ago",
    status: "Error",
    read: true,
    link: { to: "/recordings/$id", params: { id: "nora-failed" } },
  },
  {
    id: "n4",
    type: "quota_warning",
    title: "Quota warning",
    body: "You have used 25% of this month’s recording hours.",
    time: "2d ago",
    status: "Waiting",
    read: true,
    link: { to: "/usage" },
  },
];

// ---------- Usage & subscription ----------
export type UsageSummary = {
  periodStart: string;
  periodEnd: string;
  resetsOn: string;
  recordingHours: { used: number; limit: number };
  downloadGb: { used: number; limit: number };
  channels: { used: number; limit: number };
  concurrent: { active: number; limit: number };
  retentionDays: number;
  storageGb: number;
};
export const usage: UsageSummary = {
  periodStart: "Sep 1, 2026",
  periodEnd: "Sep 30, 2026",
  resetsOn: "Oct 1, 2026",
  recordingHours: { used: 12.6, limit: planCatalog.pro.quotas.recordingHours ?? 0 },
  downloadGb: { used: 24.8, limit: planCatalog.pro.quotas.downloadGb ?? 0 },
  channels: { used: 3, limit: planCatalog.pro.quotas.monitoredChannels ?? 0 },
  concurrent: { active: 1, limit: planCatalog.pro.quotas.simultaneousRecordings ?? 0 },
  retentionDays: planCatalog.pro.quotas.retentionDays,
  storageGb: 18.4,
};
export const dailyRecordingHours = [
  0.6, 1.9, 1.2, 2.6, 0.8, 3.4, 2.1, 1.4, 3.9, 2.2, 1.6, 3.1, 0.9, 4.3, 2.8, 1.8, 3.7, 2.3, 1.1,
  3.3, 2.0, 2.6, 1.4, 3.5, 2.5, 4.0, 4.6,
];

export type SubscriptionStatus = "active" | "past_due" | "canceled" | "incomplete";
export type Subscription = {
  plan: "Free" | "Pro";
  status: SubscriptionStatus;
  interval: "month" | "year";
  priceMonthly: number;
  priceYearly: number | null;
  currentPeriodEnd: string;
  cancelAtPeriodEnd: boolean;
  paymentMethod: { brand: string; last4: string; exp: string } | null;
};
export const subscription: Subscription = {
  plan: "Pro",
  status: "active",
  interval: "month",
  priceMonthly: planCatalog.pro.priceMonthlyUsd,
  priceYearly: planCatalog.pro.priceYearlyUsd,
  currentPeriodEnd: "Oct 1, 2026",
  cancelAtPeriodEnd: false,
  paymentMethod: { brand: "Visa", last4: "4242", exp: "09/29" },
};
export type Plan = (typeof planList)[number];
export const plans = planList;
export type BillingInvoice = {
  id: string;
  date: string;
  description: string;
  amount: string;
  status: "Paid" | "Failed" | "Refunded";
};
export const invoices: BillingInvoice[] = [
  {
    id: "INV-2026-0009",
    date: "Sep 1, 2026",
    description: "Pro · Monthly",
    amount: "$9.99",
    status: "Paid",
  },
  {
    id: "INV-2026-0008",
    date: "Aug 1, 2026",
    description: "Pro · Monthly",
    amount: "$9.99",
    status: "Paid",
  },
  {
    id: "INV-2026-0007",
    date: "Jul 1, 2026",
    description: "Pro · Monthly",
    amount: "$9.99",
    status: "Paid",
  },
];

// ---------- Sessions ----------
export type Session = {
  id: string;
  device: string;
  location: string;
  lastActive: string;
  current: boolean;
};
export const sessions: Session[] = [
  {
    id: "s1",
    device: "Chrome on macOS",
    location: "Ho Chi Minh City, VN",
    lastActive: "Active now",
    current: true,
  },
  {
    id: "s2",
    device: "Safari on iPhone",
    location: "Ho Chi Minh City, VN",
    lastActive: "2h ago",
    current: false,
  },
  {
    id: "s3",
    device: "Firefox on Windows",
    location: "Hanoi, VN",
    lastActive: "6 days ago",
    current: false,
  },
];

// ---------- Admin / operations ----------
export type WorkerStatus = "Recording" | "Processing" | "Idle" | "Offline" | "Draining";
export type Worker = {
  id: string;
  kind: "recorder" | "processor";
  status: WorkerStatus;
  currentJob: string | null;
  cpu: string;
  memory: string;
  heartbeat: string;
  version: string;
  region: string;
};
export const workerList: Worker[] = [
  {
    id: "recorder-03",
    kind: "recorder",
    status: "Recording",
    currentJob: "job_9KD21A",
    cpu: "34%",
    memory: "1.8 GB",
    heartbeat: "8s ago",
    version: "v1.0.3",
    region: "sgp-1",
  },
  {
    id: "recorder-01",
    kind: "recorder",
    status: "Idle",
    currentJob: null,
    cpu: "8%",
    memory: "620 MB",
    heartbeat: "4s ago",
    version: "v1.0.3",
    region: "sgp-1",
  },
  {
    id: "recorder-02",
    kind: "recorder",
    status: "Idle",
    currentJob: null,
    cpu: "11%",
    memory: "710 MB",
    heartbeat: "7s ago",
    version: "v1.0.3",
    region: "sgp-1",
  },
  {
    id: "processor-01",
    kind: "processor",
    status: "Processing",
    currentJob: "job_7HX29K",
    cpu: "47%",
    memory: "2.4 GB",
    heartbeat: "3s ago",
    version: "v1.0.3",
    region: "sgp-1",
  },
  {
    id: "recorder-04",
    kind: "recorder",
    status: "Offline",
    currentJob: null,
    cpu: "—",
    memory: "—",
    heartbeat: "14m ago",
    version: "v1.0.2",
    region: "sgp-1",
  },
];

export type JobStatus = "Recording" | "Processing" | "Ready" | "Error";
export type JobEvent = {
  time: string;
  label: string;
  state: "done" | "active" | "pending" | "failed";
};
export type RecordingJob = {
  id: string;
  user: string;
  channel: string;
  worker: string;
  status: JobStatus;
  started: string;
  ended: string | null;
  duration: string;
  retries: number;
  heartbeat: string;
  stuck: boolean;
  error: string | null;
  roomId: string;
  sourceRef: string;
  bytes: string;
  recordingId: string | null;
  timeline: JobEvent[];
};
const fullTimeline = (end: "ready" | "recording" | "processing" | "failed"): JobEvent[] => {
  const steps = [
    ["13:22:10", "Live detected"],
    ["13:22:13", "Job queued"],
    ["13:22:15", "Worker assigned"],
    ["13:22:16", "Stream resolved"],
    ["13:22:17", "Recording started"],
    ["15:36:41", "Stream ended"],
    ["15:36:44", "Processing started"],
    ["15:38:02", "Uploaded"],
    ["15:38:03", "Ready"],
  ] as const;
  const stop = end === "recording" ? 4 : end === "processing" ? 6 : end === "failed" ? 5 : 8;
  return steps.map(([time, label], i) => ({
    time: i <= stop ? time : "—",
    label,
    state:
      i < stop
        ? "done"
        : i === stop
          ? end === "ready"
            ? "done"
            : end === "failed"
              ? "failed"
              : "active"
          : "pending",
  }));
};
export const jobList: RecordingJob[] = [
  {
    id: "job_9KD21A",
    user: "Alex Nguyen",
    channel: "@linastudio",
    worker: "recorder-03",
    status: "Recording",
    started: "13:22",
    ended: null,
    duration: "01:42:18",
    retries: 0,
    heartbeat: "8s ago",
    stuck: false,
    error: null,
    roomId: "room_7300915512",
    sourceRef: "flv://pull-*.tiktokcdn…/stream-…",
    bytes: "3.8 GB",
    recordingId: "lina-sep27",
    timeline: fullTimeline("recording"),
  },
  {
    id: "job_7HX29K",
    user: "Alex Nguyen",
    channel: "@norashop",
    worker: "processor-01",
    status: "Processing",
    started: "16:48",
    ended: "17:36",
    duration: "00:48:11",
    retries: 0,
    heartbeat: "3s ago",
    stuck: false,
    error: null,
    roomId: "room_7300882104",
    sourceRef: "flv://pull-*.tiktokcdn…/stream-…",
    bytes: "1.7 GB",
    recordingId: "nora-processing",
    timeline: fullTimeline("processing"),
  },
  {
    id: "job_5MN04R",
    user: "Jordan Park",
    channel: "@jordanplays",
    worker: "recorder-01",
    status: "Recording",
    started: "12:05",
    ended: null,
    duration: "03:10:44",
    retries: 1,
    heartbeat: "4m ago",
    stuck: true,
    error: null,
    roomId: "room_7300712290",
    sourceRef: "flv://pull-*.tiktokcdn…/stream-…",
    bytes: "5.2 GB",
    recordingId: null,
    timeline: fullTimeline("recording"),
  },
  {
    id: "job_4QZ18P",
    user: "Maya Chen",
    channel: "@mayacooks",
    worker: "recorder-02",
    status: "Ready",
    started: "11:06",
    ended: "13:11",
    duration: "02:04:52",
    retries: 0,
    heartbeat: "2h ago",
    stuck: false,
    error: null,
    roomId: "room_7300650031",
    sourceRef: "flv://pull-*.tiktokcdn…/stream-…",
    bytes: "4.1 GB",
    recordingId: null,
    timeline: fullTimeline("ready"),
  },
  {
    id: "job_2BT66E",
    user: "Sam Lee",
    channel: "@samreviews",
    worker: "recorder-01",
    status: "Error",
    started: "09:41",
    ended: "10:28",
    duration: "00:47:03",
    retries: 2,
    heartbeat: "4h ago",
    stuck: false,
    error: "STREAM_DISCONNECTED · Upstream closed connection after 3 reconnect attempts",
    roomId: "room_7300598844",
    sourceRef: "flv://pull-*.tiktokcdn…/stream-…",
    bytes: "1.6 GB (partial)",
    recordingId: null,
    timeline: fullTimeline("failed"),
  },
];

export type EventSeverity = "Critical" | "Error" | "Warning" | "Info";
export type SystemEvent = {
  id: string;
  timestamp: string;
  severity: EventSeverity;
  service: string;
  target: string;
  code: string;
  message: string;
  state: "Retrying" | "Resolved" | "Open";
  details: string;
};
export const systemEvents: SystemEvent[] = [
  {
    id: "evt_1041",
    timestamp: "Sep 27 · 13:58:02",
    severity: "Warning",
    service: "recorder-01",
    target: "job_5MN04R",
    code: "HEARTBEAT_STALE",
    message: "No heartbeat received for 4 minutes",
    state: "Open",
    details: "worker.heartbeat.last=13:54:01Z\nthreshold=120s\naction=pending_reassignment",
  },
  {
    id: "evt_1040",
    timestamp: "Sep 27 · 13:12:40",
    severity: "Error",
    service: "monitor",
    target: "@norashop",
    code: "LIVE_CHECK_FAILED",
    message: "Live status check returned HTTP 503",
    state: "Retrying",
    details: "GET live-status → 503 Service Unavailable\nretry=3/5 backoff=60s",
  },
  {
    id: "evt_1039",
    timestamp: "Sep 27 · 10:28:11",
    severity: "Error",
    service: "recorder-01",
    target: "job_2BT66E",
    code: "STREAM_DISCONNECTED",
    message: "Upstream closed connection after 3 reconnect attempts",
    state: "Resolved",
    details: "ffmpeg exited code=1\nreconnect_attempts=3\npartial_output=1.6GB saved",
  },
  {
    id: "evt_1038",
    timestamp: "Sep 27 · 08:02:55",
    severity: "Critical",
    service: "storage",
    target: "job_4QZ18P",
    code: "UPLOAD_FAILED",
    message: "Multipart upload timed out, retried successfully",
    state: "Resolved",
    details: "part=14/32 timeout=30s\nretry=1 succeeded",
  },
  {
    id: "evt_1037",
    timestamp: "Sep 26 · 22:40:19",
    severity: "Info",
    service: "api",
    target: "—",
    code: "RATE_LIMITED",
    message: "Client exceeded request rate for /recordings",
    state: "Resolved",
    details: "limit=120/min observed=164/min",
  },
];

export type ServiceStatus = {
  name: string;
  state: "Operational" | "Degraded" | "Outage";
  note: string;
};
export const publicServices: ServiceStatus[] = [
  { name: "API", state: "Operational", note: "All requests serving normally" },
  { name: "Monitoring", state: "Degraded", note: "Some live checks are slower than usual" },
  { name: "Recording workers", state: "Operational", note: "4 of 4 regions healthy" },
  { name: "Processing", state: "Operational", note: "Queue within normal range" },
  { name: "Storage", state: "Operational", note: "Uploads and downloads normal" },
];

// Legacy tuple shapes kept for compatibility with older screens.
export const workers = workerList.map((w) => [
  w.id,
  w.status,
  w.currentJob ?? "—",
  w.cpu,
  w.memory,
  w.heartbeat,
  w.version,
]);
export const jobs = jobList.map((j) => [
  j.id,
  j.user,
  j.channel,
  j.worker,
  j.status,
  j.started,
  j.duration,
  String(j.retries),
  j.heartbeat,
  j.error ?? "—",
]);

/** In-progress recording shown on the active-recording screen. */
export const activeRecording: Recording = {
  id: "lina-live",
  channelId: "lina",
  handle: "@linastudio",
  title: "Live now",
  date: "Sep 27, 2026",
  time: "13:22",
  duration: "01:42:18",
  size: "3.8 GB",
  sizeGb: 3.8,
  resolution: "1080p",
  expires: "—",
  expiresDays: null,
  status: "Recording",
  color: "bg-thumbnail-one",
};