import { useEffect, useSyncExternalStore } from "react";

import { useNotificationRecordingFeedData } from "@/hooks/use-domain-data";
import { isDemoMode } from "@/lib/app-config";
import {
  notifications as demoNotifications,
  type Notification,
} from "@/mocks/fixtures";
import type { RecordingModel } from "@/repositories";

const MAX_SESSION_NOTIFICATIONS = 50;

let state: Notification[] = isDemoMode
  ? demoNotifications.map((item) => ({ ...item }))
  : [];
let initializedRecordingSnapshot = false;
let previousRecordingStatuses = new Map<string, RecordingModel["backendStatus"]>();
let sequence = 0;

const subscribers = new Set<() => void>();
const emit = () => subscribers.forEach((subscriber) => subscriber());

function realtimeNotification(
  recording: RecordingModel,
): Notification | null {
  const handle = recording.handle || "This channel";
  const common = {
    id: `session-${recording.id}-${recording.backendStatus}-${++sequence}`,
    time: "Just now",
    read: false,
    link: {
      to: "/recordings/$id" as const,
      params: { id: recording.id },
    },
  };

  if (recording.backendStatus === "recording") {
    return {
      ...common,
      type: "recording_started",
      title: "Recording started",
      body: `${handle} is live and recording has started.`,
      status: "Recording",
    };
  }

  if (recording.backendStatus === "completed") {
    return {
      ...common,
      type: "recording_ready",
      title: "Recording ready",
      body: `${handle} finished recording and the recording is ready.`,
      status: "Ready",
    };
  }

  if (
    recording.backendStatus === "failed" ||
    recording.backendStatus === "stopped"
  ) {
    return {
      ...common,
      type: "recording_failed",
      title: "Recording ended",
      body:
        recording.backendStatus === "failed"
          ? `${handle} recording failed. Open the recording for details.`
          : `${handle} recording stopped before completion.`,
      status: "Error",
    };
  }

  return null;
}

function syncRecordingTransitions(recordings: RecordingModel[]) {
  if (isDemoMode) return;

  const nextStatuses = new Map<string, RecordingModel["backendStatus"]>();
  for (const recording of recordings) {
    nextStatuses.set(recording.id, recording.backendStatus);
  }

  if (!initializedRecordingSnapshot) {
    initializedRecordingSnapshot = true;
    previousRecordingStatuses = nextStatuses;
    return;
  }

  const additions: Notification[] = [];
  for (const recording of recordings) {
    const previousStatus = previousRecordingStatuses.get(recording.id);
    if (previousStatus === recording.backendStatus) continue;

    const notification = realtimeNotification(recording);
    if (notification) additions.push(notification);
  }

  previousRecordingStatuses = nextStatuses;
  if (!additions.length) return;

  state = [...additions.reverse(), ...state].slice(0, MAX_SESSION_NOTIFICATIONS);
  emit();
}

export const notificationStore = {
  subscribe(subscriber: () => void) {
    subscribers.add(subscriber);
    return () => {
      subscribers.delete(subscriber);
    };
  },
  get: () => state,
  markRead(id: string) {
    state = state.map((notification) =>
      notification.id === id ? { ...notification, read: true } : notification,
    );
    emit();
  },
  markAllRead() {
    state = state.map((notification) => ({ ...notification, read: true }));
    emit();
  },
  syncRecordingTransitions,
};

export function useNotifications() {
  const query = useNotificationRecordingFeedData();
  const notifications = useSyncExternalStore(
    notificationStore.subscribe,
    notificationStore.get,
    notificationStore.get,
  );

  useEffect(() => {
    if (isDemoMode || !query.data) return;
    notificationStore.syncRecordingTransitions(query.data);
  }, [query.data]);

  return notifications;
}
