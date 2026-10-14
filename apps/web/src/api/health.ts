import { apiBaseUrl } from "@/lib/app-config";

export type ReadinessResponse = {
  status: "ok" | "error";
  components: Record<string, { status: "ok" | "error"; detail?: string | null }>;
};

/**
 * Public `/health/ready` check used by the status page. A 503 still carries
 * the component breakdown, so read the body regardless of status; null when
 * the API can't be reached at all.
 */
export async function fetchReadiness(): Promise<ReadinessResponse | null> {
  try {
    const response = await fetch(`${apiBaseUrl}/health/ready`, { credentials: "omit" });
    return (await response.json()) as ReadinessResponse;
  } catch {
    return null;
  }
}
