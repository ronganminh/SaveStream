import { useMutation, useQueryClient } from "@tanstack/react-query";

import { authApi } from "@/api/auth";
import { ApiError } from "@/api/errors";
import { domainQueryKeys } from "@/hooks/use-domain-data";
import { repositories } from "@/repositories";

export function useUpdateProfileMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { display_name?: string | null; locale?: string | null }) =>
      repositories.users.updateCurrent(input),
    onSuccess: async (user) => {
      queryClient.setQueryData(domainQueryKeys.currentUser, user);
      await queryClient.invalidateQueries({ queryKey: domainQueryKeys.currentUser });
    },
  });
}

export function useRevokeSessionMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (sessionId: string) => repositories.users.revokeSession(sessionId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: domainQueryKeys.sessions });
    },
  });
}

export function useExportAccountMutation() {
  return useMutation({
    mutationFn: () => repositories.users.exportData(),
  });
}

export function useDeleteAccountMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => repositories.users.requestDeletion(),
    onSuccess: () => {
      queryClient.removeQueries({ queryKey: domainQueryKeys.currentUser });
      queryClient.removeQueries({ queryKey: domainQueryKeys.sessions });
    },
  });
}

export function useResendVerificationMutation() {
  return useMutation({
    mutationFn: (email: string) => authApi.resendVerification(email),
  });
}

export function useRequestPasswordResetMutation() {
  return useMutation({
    mutationFn: (email: string) => authApi.forgotPassword(email),
  });
}

export function accountActionErrorMessage(error: unknown) {
  if (!(error instanceof ApiError)) {
    return error instanceof Error
      ? error.message
      : "The account action could not be completed.";
  }
  if (error.status === 0) {
    return "Unable to reach SaveStream. Check your connection and try again.";
  }
  if (error.code === "RATE_LIMITED") {
    return "Too many requests. Please wait a moment and try again.";
  }
  if (error.status === 404) {
    return "The requested account resource no longer exists.";
  }
  if (error.status >= 500 || error.retryable) {
    return "SaveStream is temporarily unavailable. Please try again.";
  }
  return error.serverMessage || "The account action could not be completed.";
}
