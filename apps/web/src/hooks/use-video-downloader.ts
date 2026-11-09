import { useQuery } from "@tanstack/react-query";

import { videoDownloaderApi } from "@/api/video-downloader";
import { useSignedIn } from "@/hooks/use-signed-in";
import { apiConfigured } from "@/lib/app-config";
import { downloaderEnabled } from "@/lib/video-downloader";

export const videoDownloaderKeys = {
  status: ["video-downloader", "status"] as const,
  myChannels: ["video-downloader", "my-channels"] as const,
};

/**
 * Downloader kill switch. `enabled` is true only after the status call
 * succeeded with enabled:true; while loading, on error or 404 it is false, so
 * the Free tools links stay hidden and the page shows the "not available" notice.
 */
export function useVideoDownloaderStatus() {
  const query = useQuery({
    queryKey: videoDownloaderKeys.status,
    queryFn: () => videoDownloaderApi.status(),
    enabled: apiConfigured,
    staleTime: 5 * 60_000,
    retry: false,
  });
  return {
    query,
    status: query.data ?? null,
    enabled: downloaderEnabled(query.data),
    loading: apiConfigured && query.isPending,
  };
}

/** Verified, unblocked channels for "Download my videos". */
export function useMyDownloadChannels(enabled = true) {
  const signedIn = useSignedIn();
  return useQuery({
    queryKey: videoDownloaderKeys.myChannels,
    queryFn: async () => (await videoDownloaderApi.myChannels()).items,
    enabled: signedIn && apiConfigured && enabled,
    retry: false,
  });
}
