import type { Channel, NotificationItem, Recording, RecordingJob, Worker } from "./types";

export const user = {
  name: "Alex Nguyen",
  email: "alex@savestream.app",
  initials: "AN",
  plan: "Pro",
};

export const channels: Channel[] = [
  {
    id: "lina",
    name: "Lina Studio",
    handle: "@linastudio",
    initials: "LS",
    status: "Recording",
    monitoring: true,
    checked: "Now",
    lastLive: "Live now · 01:42:18",
    recordings: 11,
  },
  {
    id: "mike",
    name: "Mike Fitness",
    handle: "@mikefitness",
    initials: "MF",
    status: "Waiting",
    monitoring: true,
    checked: "20s ago",
    lastLive: "Yesterday, 20:15",
    recordings: 4,
  },
  {
    id: "nora",
    name: "Nora Shop",
    handle: "@norashop",
    initials: "NS",
    status: "Offline",
    monitoring: true,
    checked: "32s ago",
    lastLive: "Sep 24, 11:04",
    recordings: 3,
  },
];

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
    resolution: "1080p",
    expires: "29 days",
    status: "Ready",
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
    resolution: "720p",
    expires: "28 days",
    status: "Ready",
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
    resolution: "1080p",
    expires: "3 days",
    status: "Ready",
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
    resolution: "1080p",
    expires: "—",
    status: "Processing",
  },
];

export const notifications: NotificationItem[] = [
  {
    id: "n1",
    title: "Recording started",
    body: "@linastudio is live and cloud recording has started.",
    time: "1h ago",
    status: "Recording",
    read: false,
  },
  {
    id: "n2",
    title: "Recording ready",
    body: "Your 2h 14m livestream recording is ready to watch.",
    time: "Yesterday",
    status: "Ready",
    read: false,
  },
  {
    id: "n3",
    title: "Quota warning",
    body: "You have used 80% of this month's recording hours.",
    time: "2d ago",
    status: "Waiting",
    read: true,
  },
];

export const workers: Worker[] = [
  { id: "recorder-03", status: "Recording", currentJob: "job_9KD21A", cpu: "34%", memory: "1.8 GB", heartbeat: "8s ago", version: "v1.0.0" },
  { id: "recorder-01", status: "Idle", currentJob: null, cpu: "8%", memory: "620 MB", heartbeat: "4s ago", version: "v1.0.0" },
  { id: "processor-01", status: "Processing", currentJob: "job_7HX29K", cpu: "47%", memory: "2.4 GB", heartbeat: "3s ago", version: "v1.0.0" },
  { id: "recorder-04", status: "Offline", currentJob: null, cpu: "—", memory: "—", heartbeat: "14m ago", version: "v0.9.9" },
];

export const jobs: RecordingJob[] = [
  { id: "job_9KD21A", user: "Alex Nguyen", channel: "@linastudio", worker: "recorder-03", status: "Recording", started: "13:22", duration: "01:42:18", retries: 0, heartbeat: "8s ago", error: null },
  { id: "job_7HX29K", user: "Alex Nguyen", channel: "@norashop", worker: "processor-01", status: "Processing", started: "16:48", duration: "00:48:11", retries: 0, heartbeat: "3s ago", error: null },
  { id: "job_4QZ18P", user: "Maya Chen", channel: "@mayacooks", worker: "recorder-01", status: "Ready", started: "11:06", duration: "02:04:52", retries: 0, heartbeat: "2h ago", error: null },
  { id: "job_2BT66E", user: "Sam Lee", channel: "@samreviews", worker: "recorder-01", status: "Error", started: "09:41", duration: "00:47:03", retries: 2, heartbeat: "4h ago", error: "Stream disconnected" },
];
