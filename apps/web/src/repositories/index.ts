import { isDemoMode } from "@/lib/app-config";
import { apiRepositories } from "@/repositories/api";
import { demoRepositories } from "@/repositories/demo";

export const repositories = isDemoMode ? demoRepositories : apiRepositories;

export type {
  AdminRepository,
  BillingRepository,
  ChannelModel,
  ChannelRepository,
  ChannelStatus,
  CreditsRepository,
  FilteredPageOptions,
  NotificationModel,
  NotificationRepository,
  PageOptions,
  PricingRepository,
  RecordingModel,
  RecordingRepository,
  RecordingStatus,
  SaveStreamRepositories,
  Status,
  UsageData,
  UsageRepository,
  UsageSummary,
  UsersRepository,
} from "@/repositories/contracts";
