import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { apiClient } from "@/api/client";
import type { ChannelVerificationResponse } from "@/api/types";
import { domainQueryKeys } from "@/hooks/use-domain-data";
import { useSignedIn } from "@/hooks/use-signed-in";
import { isDemoMode } from "@/lib/app-config";

// Channel ownership: the owner pastes a one-time code (SS-XXXX) in the
// TikTok bio and SaveStream checks it server-side.

export const channelVerificationKey = (watchId: string) =>
  ["channels", watchId, "verification"] as const;

export function useChannelVerification(watchId: string | null | undefined, enabled = true) {
  const signedIn = useSignedIn();
  return useQuery({
    queryKey: channelVerificationKey(watchId ?? "missing"),
    queryFn: () =>
      apiClient.get<ChannelVerificationResponse>(`/v1/watches/${watchId}/verification`),
    enabled: Boolean(watchId) && enabled && signedIn && !isDemoMode,
  });
}

export function useChannelVerificationActions(watchId: string) {
  const queryClient = useQueryClient();
  const store = async (result: ChannelVerificationResponse) => {
    queryClient.setQueryData(channelVerificationKey(watchId), result);
    if (result.verified) {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.channels }),
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.channel(watchId) }),
      ]);
    }
  };
  const start = useMutation({
    mutationFn: () =>
      apiClient.post<ChannelVerificationResponse>(`/v1/watches/${watchId}/verification`),
    onSuccess: store,
  });
  const check = useMutation({
    mutationFn: () =>
      apiClient.post<ChannelVerificationResponse>(`/v1/watches/${watchId}/verification/check`),
    onSuccess: store,
  });
  return { start, check };
}
