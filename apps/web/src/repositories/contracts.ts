import type {
  Channel,
  Notification,
  Recording,
  UsageSummary,
} from "@/mocks/fixtures";

export type UsageData = {
  summary: UsageSummary;
  dailyRecordingHours: readonly number[];
};

export interface ChannelRepository {
  list(): Promise<Channel[]>;
  getById(id: string): Promise<Channel | null>;
}

export interface RecordingRepository {
  list(): Promise<Recording[]>;
  getById(id: string): Promise<Recording | null>;
  getActive(): Promise<Recording | null>;
}

export interface UsageRepository {
  getCurrent(): Promise<UsageData>;
}

export interface NotificationRepository {
  list(): Promise<Notification[]>;
  markRead(id: string): Promise<void>;
  markAllRead(): Promise<void>;
}

export interface SaveStreamRepositories {
  channels: ChannelRepository;
  recordings: RecordingRepository;
  usage: UsageRepository;
  notifications: NotificationRepository;
}
