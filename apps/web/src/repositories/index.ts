import { isDemoMode } from "@/lib/app-config";
import type { SaveStreamRepositories } from "@/repositories/contracts";

let repositoryPromise: Promise<SaveStreamRepositories> | null = null;

export function getRepositories(): Promise<SaveStreamRepositories> {
  if (!repositoryPromise) {
    repositoryPromise = isDemoMode
      ? import("@/repositories/demo").then((module) => module.demoRepositories)
      : import("@/repositories/api").then((module) => module.apiRepositories);
  }
  return repositoryPromise;
}

export type {
  ChannelRepository,
  NotificationRepository,
  RecordingRepository,
  SaveStreamRepositories,
  UsageData,
  UsageRepository,
} from "@/repositories/contracts";
