import { isDemoMode } from "@/lib/app-config";
import { apiRepositories } from "@/repositories/api";
import { demoRepositories } from "@/repositories/demo";

export const repositories = isDemoMode ? demoRepositories : apiRepositories;

export type {
  ChannelRepository,
  NotificationRepository,
  RecordingRepository,
  SaveStreamRepositories,
  UsageData,
  UsageRepository,
} from "@/repositories/contracts";
