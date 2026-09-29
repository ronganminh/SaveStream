import { Play, X } from "lucide-react";
import { useEffect, useState } from "react";
import { SaveStreamMark } from "./brand";
import { StatusBadge } from "./ui";
import { recordings } from "../lib/mock-data";
import { sampleMedia, type SampleMediaItem } from "../lib/sample-media";
import { usePreferences } from "../lib/preferences";

export function SampleMediaGrid({ sampleLabel }: { sampleLabel: string }) {
  const { locale } = usePreferences();
  const [selected, setSelected] = useState<SampleMediaItem | null>(null);
  const copy = locale === "vi"
    ? {
        preview: "Xem demo",
        demo: "Bản ghi demo",
        close: "Đóng bản xem trước",
        source: "Nguồn",
        duration: "Thời lượng bản ghi",
        note: "Đây là đoạn preview ngắn được tạo từ một livestream đã ghi thật.",
      }
    : {
        preview: "Watch demo",
        demo: "Demo recording",
        close: "Close preview",
        source: "Source",
        duration: "Recording duration",
        note: "This is a short preview generated from a real recorded livestream.",
      };

  useEffect(() => {
    if (!selected) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setSelected(null);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [selected]);

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
    <>
      <div className="mt-10 grid gap-5 md:grid-cols-2 xl:grid-cols-3 lg:gap-6">
        {sampleMedia.slice(0, 6).map((item, index) => (
          <article key={item.id} className="group overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)] shadow-sm transition hover:-translate-y-0.5 hover:shadow-xl">
            <button
              type="button"
              onClick={() => setSelected(item)}
              className="relative block aspect-video w-full overflow-hidden bg-slate-950 text-left focus:outline-none focus:ring-2 focus:ring-inset focus:ring-indigo-400"
              aria-label={`${copy.preview}: ${sampleLabel} ${index + 1}`}
            >
              <img
                src={item.thumbnailUrl}
                alt=""
                loading="lazy"
                className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.02]"
              />
              <span className="absolute inset-0 bg-gradient-to-t from-black/55 via-transparent to-black/5 opacity-80" />
              <span className="absolute left-1/2 top-1/2 grid size-12 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full bg-white/95 text-slate-950 shadow-lg transition group-hover:scale-105">
                <Play className="ml-0.5 size-5 fill-current" />
              </span>
              <span className="absolute bottom-3 left-3 inline-flex items-center gap-1.5 rounded-full bg-black/65 px-2.5 py-1 text-xs font-medium text-white backdrop-blur">
                <Play className="size-3 fill-current" /> {copy.preview}
              </span>
            </button>

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

      {selected && (
        <div className="fixed inset-0 z-[90] flex items-end justify-center bg-slate-950/70 p-0 backdrop-blur-sm sm:items-center sm:p-6" onMouseDown={() => setSelected(null)}>
          <section
            role="dialog"
            aria-modal="true"
            aria-label={copy.demo}
            className="max-h-[94vh] w-full overflow-y-auto rounded-t-2xl border border-[var(--border)] bg-[var(--surface)] shadow-2xl sm:max-w-5xl sm:rounded-2xl"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <div className="flex items-center justify-between gap-4 border-b border-[var(--border)] px-5 py-4">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <h3 className="truncate font-semibold">{copy.demo}</h3>
                  <StatusBadge status="Ready" />
                </div>
                <p className="mt-1 text-xs text-[var(--muted)]">{copy.note}</p>
              </div>
              <button type="button" onClick={() => setSelected(null)} className="grid size-9 shrink-0 place-items-center rounded-lg hover:bg-[var(--subtle)]" aria-label={copy.close}>
                <X className="size-4" />
              </button>
            </div>

            <div className="bg-black">
              {selected.kind === "video" ? (
                <video
                  key={selected.id}
                  className="mx-auto max-h-[68vh] w-full object-contain"
                  controls
                  autoPlay
                  playsInline
                  preload="metadata"
                  poster={selected.thumbnailUrl}
                >
                  <source src={selected.mediaUrl} type="video/mp4" />
                </video>
              ) : (
                <img src={selected.thumbnailUrl} alt={selected.title} className="mx-auto max-h-[68vh] w-full object-contain" />
              )}
            </div>

            <div className="grid gap-4 p-5 sm:grid-cols-3 sm:p-6">
              <div>
                <p className="text-xs text-[var(--muted)]">{copy.source}</p>
                <p className="mt-1 font-mono text-sm font-medium">{selected.width}×{selected.height}</p>
              </div>
              <div>
                <p className="text-xs text-[var(--muted)]">{copy.duration}</p>
                <p className="mt-1 font-mono text-sm font-medium">{selected.durationSeconds ? formatDuration(selected.durationSeconds) : "—"}</p>
              </div>
              <div>
                <p className="text-xs text-[var(--muted)]">ID</p>
                <p className="mt-1 font-mono text-sm font-medium">{selected.id}</p>
              </div>
            </div>
          </section>
        </div>
      )}
    </>
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
