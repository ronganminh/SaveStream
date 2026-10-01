import { useSyncExternalStore } from "react";
import { notifications as seed, type Notification } from "./mock-data";

// In-memory notification state shared by the topbar bell and /notifications.
// Replace with an API-backed query once the backend exists.
let state: Notification[] = seed;
const subs = new Set<() => void>();
const emit = () => subs.forEach((f) => f());

export const notificationStore = {
  subscribe(f: () => void) { subs.add(f); return () => { subs.delete(f); }; },
  get: () => state,
  markRead(id: string) { state = state.map((n) => (n.id === id ? { ...n, read: true } : n)); emit(); },
  markAllRead() { state = state.map((n) => ({ ...n, read: true })); emit(); },
};

export function useNotifications() {
  return useSyncExternalStore(notificationStore.subscribe, notificationStore.get, notificationStore.get);
}