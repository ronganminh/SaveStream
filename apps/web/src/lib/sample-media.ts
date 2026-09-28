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

export const sampleMedia: SampleMediaItem[] = [
  {
    "id": "video-01",
    "kind": "video",
    "title": "Recorded livestream sample 1",
    "mediaUrl": "/samples/video-01.mp4",
    "thumbnailUrl": "/samples/video-01.webp",
    "durationSeconds": 2177.6,
    "width": 640,
    "height": 1280
  },
  {
    "id": "video-02",
    "kind": "video",
    "title": "Recorded livestream sample 2",
    "mediaUrl": "/samples/video-02.mp4",
    "thumbnailUrl": "/samples/video-02.webp",
    "durationSeconds": 1412.5,
    "width": 640,
    "height": 1280
  },
  {
    "id": "video-03",
    "kind": "video",
    "title": "Recorded livestream sample 3",
    "mediaUrl": "/samples/video-03.mp4",
    "thumbnailUrl": "/samples/video-03.webp",
    "durationSeconds": 1869.4,
    "width": 640,
    "height": 1280
  },
  {
    "id": "video-04",
    "kind": "video",
    "title": "Recorded livestream sample 4",
    "mediaUrl": "/samples/video-04.mp4",
    "thumbnailUrl": "/samples/video-04.webp",
    "durationSeconds": 2151.7,
    "width": 640,
    "height": 1280
  }
];
