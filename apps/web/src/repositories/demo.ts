import {
  activeRecording,
  channels,
  dailyRecordingHours,
  notifications,
  recordings,
  usage,
  type Notification,
} from "@/mocks/fixtures";
import type { SaveStreamRepositories } from "@/repositories/contracts";

let notificationState: Notification[] = notifications.map((item) => ({ ...item }));

export const demoRepositories: SaveStreamRepositories = {
  channels: {
    async list() {
      return channels.map((item) => ({ ...item }));
    },
    async getById(id) {
      const item = channels.find((channel) => channel.id === id);
      return item ? { ...item } : null;
    },
  },
  recordings: {
    async list() {
      return recordings.map((item) => ({ ...item }));
    },
    async getById(id) {
      const item = recordings.find((recording) => recording.id === id);
      return item ? { ...item } : null;
    },
    async getActive() {
      return activeRecording ? { ...activeRecording } : null;
    },
  },
  usage: {
    async getCurrent() {
      return {
        summary: structuredClone(usage),
        dailyRecordingHours: [...dailyRecordingHours],
      };
    },
  },
  notifications: {
    async list() {
      return notificationState.map((item) => ({ ...item }));
    },
    async markRead(id) {
      notificationState = notificationState.map((item) =>
        item.id === id ? { ...item, read: true } : item,
      );
    },
    async markAllRead() {
      notificationState = notificationState.map((item) => ({ ...item, read: true }));
    },
  },
};
