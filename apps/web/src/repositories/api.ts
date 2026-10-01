import type { SaveStreamRepositories } from "@/repositories/contracts";

export class BackendUnavailableError extends Error {
  constructor() {
    super("SaveStream backend repositories are not connected.");
    this.name = "BackendUnavailableError";
  }
}

const unavailable = async <T>(): Promise<T> => {
  throw new BackendUnavailableError();
};

export const apiRepositories: SaveStreamRepositories = {
  channels: {
    list: () => unavailable(),
    getById: () => unavailable(),
  },
  recordings: {
    list: () => unavailable(),
    getById: () => unavailable(),
    getActive: () => unavailable(),
  },
  usage: {
    getCurrent: () => unavailable(),
  },
  notifications: {
    list: () => unavailable(),
    markRead: () => unavailable(),
    markAllRead: () => unavailable(),
  },
};
