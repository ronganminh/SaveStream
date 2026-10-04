import { useQuery, type UseQueryResult } from "@tanstack/react-query";
import type { AsyncResourceState } from "@/domain/resource-state";
import { isDemoMode } from "@/lib/app-config";
import { repositories, type RecordingModel } from "@/repositories";
import { useSignedIn } from "@/hooks/use-signed-in";

export const domainQueryKeys = {
  channels: ["channels"] as const,
  channel: (id: string) => ["channels", id] as const,
  recordings: ["recordings"] as const,
  recording: (id: string) => ["recordings", id] as const,
  recordingArtifacts: (id: string) => ["recordings", id, "artifacts"] as const,
  activeRecording: ["recordings", "active"] as const,
  creditBalance: ["credits", "balance"] as const,
  creditTransactions: ["credits", "transactions"] as const,
  creditReservations: ["credits", "reservations"] as const,
  pricing: ["pricing"] as const,
  publicPricing: ["pricing", "public"] as const,
  creditPackages: ["billing", "packages"] as const,
  paymentOrders: ["billing", "payment-orders"] as const,
  paymentOrder: (id: string) => ["billing", "payment-orders", id] as const,
  currentUser: ["account", "current-user"] as const,
  entitlement: ["account", "entitlement"] as const,
  sessions: ["account", "sessions"] as const,
  usage: ["usage", "current"] as const,
};

function toResourceState<T>(
  result: UseQueryResult<T, Error>,
  isEmpty: (value: T) => boolean = () => false,
): AsyncResourceState<T> {
  if (result.isPending) return { kind: "loading" };
  if (result.isError) return { kind: "error", error: result.error };
  const data = result.data;
  if (isEmpty(data)) return { kind: "empty", data };
  if (result.isFetching) return { kind: "stale", data };
  return { kind: "success", data };
}

export function useChannelsData() {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.channels,
    queryFn: () => repositories.channels.list(),
    enabled: signedIn,
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useChannelData(id: string | null | undefined) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.channel(id ?? "missing"),
    queryFn: () => repositories.channels.getById(id ?? ""),
    enabled: signedIn && Boolean(id),
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

const terminalRecordingStatuses = new Set(["completed", "failed", "stopped"]);

function needsRecordingPolling(recording: RecordingModel | null | undefined) {
  return Boolean(recording && !terminalRecordingStatuses.has(recording.backendStatus));
}

function needsRecordingsPolling(recordings: RecordingModel[] | undefined) {
  return recordings?.some(needsRecordingPolling) ?? false;
}

export function useRecordingsData() {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.recordings,
    queryFn: () => repositories.recordings.list(),
    enabled: signedIn,
    refetchInterval: (current) =>
      !isDemoMode && needsRecordingsPolling(current.state.data) ? 5000 : false,
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useRecordingData(id: string | null | undefined) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.recording(id ?? "missing"),
    queryFn: () => repositories.recordings.getById(id ?? ""),
    enabled: signedIn && Boolean(id),
    refetchInterval: (current) =>
      !isDemoMode && needsRecordingPolling(current.state.data) ? 5000 : false,
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

export function useRecordingArtifactsData(id: string | null | undefined, enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.recordingArtifacts(id ?? "missing"),
    queryFn: () => repositories.recordings.listArtifacts(id ?? ""),
    enabled: signedIn && Boolean(id) && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useActiveRecordingData() {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.activeRecording,
    queryFn: () => repositories.recordings.getActive(),
    enabled: signedIn,
    refetchInterval: (current) =>
      !isDemoMode && needsRecordingPolling(current.state.data) ? 5000 : false,
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

export function useCreditBalanceData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.creditBalance,
    queryFn: () => repositories.credits.getBalance(),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query) };
}

export function useCreditTransactionsData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.creditTransactions,
    queryFn: () => repositories.credits.listTransactions({ limit: 20 }),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function useCreditReservationsData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.creditReservations,
    queryFn: () => repositories.credits.listReservations({ limit: 20 }),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function usePricingData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.pricing,
    queryFn: () => repositories.pricing.get(),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query) };
}

/** Public catalog; intentionally available to guests. */
export function usePublicPricingData() {
  const query = useQuery({
    queryKey: domainQueryKeys.publicPricing,
    queryFn: () => repositories.pricing.getPublic(),
    staleTime: 5 * 60_000,
  });
  return { query, state: toResourceState(query, (data) => data.packages.length === 0) };
}

export function useCreditPackagesData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.creditPackages,
    queryFn: () => repositories.billing.listPackages(),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function usePaymentOrdersData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.paymentOrders,
    queryFn: () => repositories.billing.listPaymentOrders({ limit: 20 }),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function usePaymentOrderData(id: string | null | undefined, enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.paymentOrder(id ?? "missing"),
    queryFn: () => repositories.billing.getPaymentOrder(id ?? ""),
    enabled: signedIn && Boolean(id) && enabled,
    refetchInterval: (current) => {
      const status = current.state.data?.status;
      return status === "created" || status === "pending" ? 2500 : false;
    },
  });
  return { query, state: toResourceState(query) };
}

export function useEntitlementData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.entitlement,
    queryFn: () => repositories.users.getEntitlement(),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query) };
}

export function useCurrentUserData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.currentUser,
    queryFn: () => repositories.users.getCurrent(),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query) };
}

export function useSessionsData(enabled = true) {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.sessions,
    queryFn: () => repositories.users.listSessions(),
    enabled: signedIn && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function useUsageData() {
  const signedIn = useSignedIn();
  const query = useQuery({
    queryKey: domainQueryKeys.usage,
    queryFn: () => repositories.usage.getCurrent(),
    enabled: signedIn,
  });
  return { query, state: toResourceState(query) };
}
