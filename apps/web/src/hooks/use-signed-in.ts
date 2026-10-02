import { useAuth } from "@/auth/auth-context";
import { isDemoMode } from "@/lib/app-config";

/**
 * Gate for queries that need a user session. Guests and visitors whose session
 * is still being restored must not call authenticated endpoints.
 */
export function useSignedIn(): boolean {
  const { status } = useAuth();
  return isDemoMode || status === "authenticated";
}
