export type ChannelStatus = "Recording" | "Waiting" | "Offline" | "Paused" | "Error";
export type RecordingStatus = "Recording" | "Processing" | "Ready" | "Error";
export type Status = ChannelStatus | RecordingStatus;

export interface Channel {
  id: string;
  name: string;
  handle: string;
  initials: string;
  status: ChannelStatus;
  monitoring: boolean;
  checked: string;
  lastLive: string;
  recordings: number;
}

export interface Recording {
  id: string;
  channelId: string;
  handle: string;
  title: string;
  date: string;
  time: string;
  duration: string;
  size: string;
  resolution: string;
  expires: string;
  status: RecordingStatus;
}

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  time: string;
  status: Status;
  read: boolean;
}

export interface Worker {
  id: string;
  status: "Recording" | "Processing" | "Idle" | "Offline";
  currentJob: string | null;
  cpu: string;
  memory: string;
  heartbeat: string;
  version: string;
}

export interface RecordingJob {
  id: string;
  user: string;
  channel: string;
  worker: string;
  status: "Recording" | "Processing" | "Ready" | "Error";
  started: string;
  duration: string;
  retries: number;
  heartbeat: string;
  error: string | null;
}
