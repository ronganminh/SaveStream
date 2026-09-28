import type { ReactNode } from "react";
import { usePreferences } from "../lib/preferences";
import type { Status } from "../lib/types";

const statusClass: Record<Status, string> = {
  Recording: "border-red-200 bg-red-50 text-red-700 dark:border-red-500/25 dark:bg-red-500/10 dark:text-red-300",
  Processing: "border-blue-200 bg-blue-50 text-blue-700 dark:border-blue-500/25 dark:bg-blue-500/10 dark:text-blue-300",
  Ready: "border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-500/25 dark:bg-emerald-500/10 dark:text-emerald-300",
  Waiting: "border-amber-200 bg-amber-50 text-amber-700 dark:border-amber-500/25 dark:bg-amber-500/10 dark:text-amber-300",
  Offline: "border-slate-200 bg-slate-100 text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300",
  Paused: "border-slate-200 bg-slate-100 text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300",
  Error: "border-red-200 bg-red-50 text-red-700 dark:border-red-500/25 dark:bg-red-500/10 dark:text-red-300",
};

export function StatusBadge({ status }: { status: Status }) {
  const { t } = usePreferences();
  const label = {
    Recording: t("status.Recording"),
    Processing: t("status.Processing"),
    Ready: t("status.Ready"),
    Waiting: t("status.Waiting"),
    Offline: t("status.Offline"),
    Paused: t("status.Paused"),
    Error: t("status.Error"),
  }[status];

  return (
    <span className={`inline-flex h-6 shrink-0 items-center gap-1.5 whitespace-nowrap rounded-md border px-2 text-xs font-medium ${statusClass[status]}`}>
      <span className={`size-1.5 rounded-full bg-current ${status === "Recording" ? "animate-pulse" : ""}`} />
      {label}
    </span>
  );
}

export function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`overflow-hidden rounded-lg border border-[var(--border)] bg-[var(--surface)] sm:rounded-xl ${className}`}>{children}</section>;
}

export function PageHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return (
    <header className="mb-5 flex flex-col gap-4 sm:mb-6 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0">
        <h1 className="break-words text-xl font-semibold tracking-tight sm:text-2xl">{title}</h1>
        {subtitle && <p className="mt-1 max-w-2xl text-sm leading-6 text-[var(--muted)]">{subtitle}</p>}
      </div>
      {action && <div className="flex w-full flex-wrap gap-2 sm:w-auto sm:shrink-0 sm:justify-end [&>*]:flex-1 sm:[&>*]:flex-none">{action}</div>}
    </header>
  );
}

export function Progress({ value }: { value: number }) {
  return (
    <div className="h-1.5 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-800">
      <div className="h-full rounded-full bg-indigo-600 transition-[width]" style={{ width: `${Math.min(value, 100)}%` }} />
    </div>
  );
}
