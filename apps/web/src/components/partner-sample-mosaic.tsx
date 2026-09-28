import { Play, Youtube } from "lucide-react";
import { sampleMedia } from "../lib/sample-media";

export function PartnerSampleMosaic({ sampleLabel }: { sampleLabel: string }) {
  const items = sampleMedia.slice(0, 4);

  if (items.length === 0) {
    return (
      <div className="grid min-h-72 grid-cols-2 gap-px bg-[var(--border)] p-px sm:min-h-80">
        {["Long livestream", "Creator archive", "Review footage", "Recorded library"].map((label, index) => (
          <div
            key={label}
            className="relative grid place-items-center overflow-hidden bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900 p-6 text-center text-white"
          >
            <Youtube className="size-9 text-white/70" />
            <p className="mt-3 text-sm font-medium">{label}</p>
            <span className="absolute right-3 top-3 font-mono text-xs text-white/45">0{index + 1}</span>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="grid min-h-72 grid-cols-1 gap-px bg-[var(--border)] p-px sm:grid-cols-2 sm:min-h-80">
      {items.map((item, index) => (
        <article key={item.id} className="group relative min-h-56 overflow-hidden bg-slate-950 sm:min-h-48">
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
              className="h-full w-full object-cover"
            />
          )}

          <span className="pointer-events-none absolute right-3 top-3 rounded-full bg-black/65 px-2 py-1 font-mono text-[10px] text-white backdrop-blur">
            {String(index + 1).padStart(2, "0")}
          </span>

          <div className="pointer-events-none absolute inset-x-0 bottom-0 flex items-end justify-between gap-3 bg-gradient-to-t from-black/80 via-black/20 to-transparent p-3 pt-12 text-white">
            <div className="min-w-0">
              <p className="truncate text-xs font-semibold">{item.title}</p>
              <p className="mt-1 text-[10px] text-white/70">
                {item.width}×{item.height}
                {item.durationSeconds ? ` · ${formatDuration(item.durationSeconds)}` : ""}
              </p>
            </div>
            {item.kind === "video" && (
              <span className="grid size-8 shrink-0 place-items-center rounded-full bg-white/90 text-slate-950 shadow-sm">
                <Play className="ml-0.5 size-3.5 fill-current" />
              </span>
            )}
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
