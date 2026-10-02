import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { isDemoMode } from "@/lib/app-config";
import { repositories } from "@/repositories";

export const notificationQueryKeys = {
  list: ["notifications", "list"] as const,
  preferences: ["notifications", "preferences"] as const,
};

export function useNotificationsData() {
  return useQuery({
    queryKey: notificationQueryKeys.list,
    queryFn: () => repositories.notifications.list(),
    refetchInterval: isDemoMode ? false : 10_000,
  });
}

export function useNotificationPreferencesData(enabled = true) {
  return useQuery({
    queryKey: notificationQueryKeys.preferences,
    queryFn: () => repositories.notifications.getPreferences(),
    enabled,
  });
}

export function useUpdateNotificationPreferencesMutation() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      recording_started: boolean;
      recording_ready: boolean;
      recording_failed: boolean;
    }) => repositories.notifications.updatePreferences(input),
    onSuccess: (data) => {
      client.setQueryData(notificationQueryKeys.preferences, data);
    },
  });
}
