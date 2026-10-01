import type {
  Channel,
  Recording,
  SupportError,
  UsageSummary,
} from "@/domain/models";
import type {
  AddChannelState,
  DownloadLifecycleState,
} from "@/domain/lifecycles";

export type ChannelLookupResult =
  | { state: "found"; channel: Pick<Channel, "name" | "handle" | "initials" | "platform"> }
  | { state: Exclude<AddChannelState, "found" | "permission_required" | "adding" | "success" | "error"> };

export type MutationResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: SupportError };

export type DownloadResult =
  | { state: Extract<DownloadLifecycleState, "eligible" | "started"> }
  | { state: Exclude<DownloadLifecycleState, "eligible" | "started">; error?: SupportError };

export interface SaveStreamRepository {
  listChannels(): Promise<Channel[]>;
  getChannel(id: string): Promise<Channel | null>;
  listRecordings(): Promise<Recording[]>;
  getRecording(id: string): Promise<Recording | null>;
  getUsage(): Promise<UsageSummary>;
  lookupChannel(input: string): Promise<ChannelLookupResult>;
  addChannel(handle: string, authorized: boolean): Promise<MutationResult<Channel>>;
  retryRecordingProcessing(id: string): Promise<MutationResult<Recording>>;
  prepareDownload(id: string): Promise<DownloadResult>;
}

export class RepositoryError extends Error {
  readonly publicError: SupportError;

  constructor(publicError: SupportError) {
    super(publicError.title);
    this.name = "RepositoryError";
    this.publicError = publicError;
  }
}
