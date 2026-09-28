import type { ReactNode } from "react";
import type { Status } from "../lib/types";

const statusClass: Record<Status, string> = {
  Recording: "border-red-200 bg-red-50 text-red-700",
  Processing: "border-blue-200 bg-blue-50 text-blue-700",
  Ready: "border-emerald-200 bg-emerald-50 text-emerald-700",
  Waiting: "border-amber-200 bg-amber-50 text-amber-700",
  Offline: "border-slate-200 bg-slate-100 text-slate-600",
  Paused: "border-slate-200 bg-slate-100 text-slate-600",
  Error: "border-red-200 bg-red-50 text-red-700",
};

export function StatusBadge({ status }: { status: Status }) {
  return (
    <span className={`inline-flex h-6 items-center gap-1.5 rounded-md border px-2 text-xs font-medium ${statusClass[status]}`}>
      <span className={`size-1.5 rounded-full bg-current ${status === "Recording" ? "animate-pulse" : ""}`} />
      {status}
    </span>
  );
}

export function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`rounded-xl border border-[var(--border)] bg-[var(--surface)] ${className}`}>{children}</section>;
}

export function PageHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return (
    <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 max-w-2xl text-sm text-[var(--muted)]">{subtitle}</p>}
      </div>
      {action}
    </header>
  );
}

export function Progress({ value }: { value: number }) {
  return (
    <div className="h-1.5 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-800">
      <div className="h-full rounded-full bg-indigo-600" style={{ width: `${Math.min(value, 100)}%` }} />
    </div>
  );
}
