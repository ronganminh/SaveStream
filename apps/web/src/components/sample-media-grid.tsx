import { Play } from "lucide-react";
import { SaveStreamMark } from "./brand";
import { StatusBadge } from "./ui";
import { recordings } from "../lib/mock-data";
import { sampleMedia } from "../lib/sample-media";

export function SampleMediaGrid({ sampleLabel }: { sampleLabel: string }) {
  if (sampleMedia.length === 0) {
    return (
      <div className="mt-10 grid gap-5 md:grid-cols-3 lg:gap-6">
        {recordings.slice(0, 3).map((recording) => (
          <article key={recording.id} className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)]">
            <div className="relative aspect-video bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900">
              <SaveStreamMark className="absolute left-1/2 top-1/2 size-14 -translate-x-1/2 -translate-y-1/2 opacity-60" />
              <span className="absolute bottom-3 right-3 rounded bg-black/70 px-2 py-1 font-mono text-xs text-white">{recording.duration}</span>
            </div>
            <div className="p-5">
              <div className="flex items-center justify-between gap-3">
                <b>{recording.handle}</b>
                <StatusBadge status="Ready" />
              </div>
              <p className="mt-2 text-sm text-[var(--muted)]">{recording.date} · {recording.resolution}</p>
            </div>
          </article>
        ))}
      </div>
    );
  }

  return (
    <div className="mt-10 grid gap-5 md:grid-cols-2 xl:grid-cols-3 lg:gap-6">
      {sampleMedia.slice(0, 6).map((item, index) => (
        <article key={item.id} className="group overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)] shadow-sm transition hover:-translate-y-0.5 hover:shadow-xl">
          <div className="relative aspect-video overflow-hidden bg-slate-950">
            {item.kind === "video" ? (
              <video
                className="h-full w-full object-cover"
                controls
                playsInline
                preload="metadata"
                poster={item.thumbnailUrl}
                aria-label={`${sampleLabel} ${index + 1}`}
              >
                <source src={item.mediaUrl} type="video/mp4" />
              </video>
            ) : (
              <img
                src={item.thumbnailUrl}
                alt={`${sampleLabel} ${index + 1}`}
                loading="lazy"
                className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.02]"
              />
            )}
            {item.kind === "video" && (
              <span className="pointer-events-none absolute left-3 top-3 inline-flex items-center gap-1.5 rounded-full bg-black/65 px-2.5 py-1 text-xs font-medium text-white backdrop-blur">
                <Play className="size-3 fill-current" /> Preview
              </span>
            )}
          </div>
          <div className="flex items-center justify-between gap-4 p-4 sm:p-5">
            <div className="min-w-0">
              <b className="block truncate text-sm">{sampleLabel} {String(index + 1).padStart(2, "0")}</b>
              <p className="mt-1 text-xs text-[var(--muted)]">
                {item.width}×{item.height}
                {item.durationSeconds ? ` · ${formatDuration(item.durationSeconds)}` : ""}
              </p>
            </div>
            <StatusBadge status="Ready" />
          </div>
        </article>
      ))}
    </div>
  );
}

function formatDuration(seconds: number) {
  const total = Math.max(0, Math.round(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const remaining = total % 60;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m ${remaining}s`;
}
