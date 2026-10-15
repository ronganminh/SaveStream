import { useEffect, useState } from "react";

/**
 * The recording's real thumbnail, laid over its gradient placeholder.
 * The parent must be `relative overflow-hidden`; when there is no URL or the
 * image fails (expired link, not generated yet) the gradient shows through.
 */
export function RecordingThumbImage({ url }: { url?: string | null | undefined }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [url]);
  if (!url || failed) return null;
  return (
    <img
      src={url}
      alt=""
      aria-hidden="true"
      loading="lazy"
      decoding="async"
      draggable={false}
      onError={() => setFailed(true)}
      className="pointer-events-none absolute inset-0 size-full object-cover"
    />
  );
}
