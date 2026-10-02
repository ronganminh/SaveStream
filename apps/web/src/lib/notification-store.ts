import { useEffect, useSyncExternalStore } from "react";

import { useNotificationsData } from "@/hooks/use-notifications";
import { isDemoMode } from "@/lib/app-config";
import {
  notifications as demoNotifications,
  type Notification,
} from "@/mocks/fixtures";
import { repositories } from "@/repositories";

let state: Notification[] = isDemoMode
  ? demoNotifications.map((item) => ({ ...item }))
  : [];

const subscribers = new Set<() => void>();
const emit = () => subscribers.forEach((subscriber) => subscriber());

function replaceState(next: Notification[]) {
  state = next.map((item) => ({ ...item }));
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
  async markRead(id: string): Promise<boolean> {
    const previous = state;
    state = state.map((notification) =>
      notification.id === id ? { ...notification, read: true } : notification,
    );
    emit();
    try {
      await repositories.notifications.markRead(id);
      return true;
    } catch {
      state = previous;
      emit();
      return false;
    }
  },
  async markAllRead(): Promise<boolean> {
    const previous = state;
    state = state.map((notification) => ({ ...notification, read: true }));
    emit();
    try {
      await repositories.notifications.markAllRead();
      return true;
    } catch {
      state = previous;
      emit();
      return false;
    }
  },
};

export function useNotificationFeed() {
  const query = useNotificationsData();
  const notifications = useSyncExternalStore(
    notificationStore.subscribe,
    notificationStore.get,
    notificationStore.get,
  );

  useEffect(() => {
    if (!query.data) return;
    replaceState(query.data);
  }, [query.data]);

  return { notifications, query };
}

export function useNotifications() {
  return useNotificationFeed().notifications;
}
