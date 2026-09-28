export type SampleMediaKind = "video" | "image";

export interface SampleMediaItem {
  id: string;
  kind: SampleMediaKind;
  title: string;
  mediaUrl: string;
  thumbnailUrl: string;
  durationSeconds?: number;
  width: number;
  height: number;
}

// This file is replaced by the sample-media GitHub Actions workflow after it
// downloads, scores, and optimizes the shared Google Drive media.
export const sampleMedia: SampleMediaItem[] = [];
