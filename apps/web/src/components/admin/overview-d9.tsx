import { formatAdminDateTime } from "@/lib/formatters";
import { useEffect, useState } from "react";
import { AlertTriangle, CheckCircle2, Download, RefreshCw } from "lucide-react";
import { Link } from "@tanstack/react-router";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, AvatarCircle, PageHeader } from "@/components/app-components";
import {
  AdminBadge,
  AdminCard,
  AdminDataTable,
  AdminMfaGate,
  AdminMetricCard,
  AdminUserStatusBadge,
  type AdminBadgeTone,
} from "@/components/admin/foundation";
import { initials } from "@/repositories/mappers/channel";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import {
  adminD9Api,
  adminFoundationApi,
  type AdminDailyMetric,
  type AdminOverview,
  type AdminSupportReport,
  type AdminUser,
} from "@/repositories/admin-api";

function usd(minor: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(minor / 100);
}

function dateTime(value: string | null | undefined) {
  return formatAdminDateTime(value);
}

function downloadCsv(filename: string, content: string) {
  const blob = new Blob([content], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

function PermissionPanel({ children }: { children: string }) {
  return (
    <div className="rounded-[16px] border bg-surface p-6">
      <h2 className="font-medium">Permission required</h2>
      <p className="mt-2 text-sm text-muted-foreground">{children}</p>
    </div>
  );
}

type OverviewRange = 7 | 14 | 30;

type OverviewAlert = {
  key: string;
  tone: "danger" | "warning" | "info";
  title: string;
  message: string;
  href: string;
  action: string;
};

const alertTileTones: Record<OverviewAlert["tone"], string> = {
  danger: "bg-destructive/10 text-destructive",
  warning: "bg-warning-subtle text-warning-foreground",
  info: "bg-info-subtle text-info",
};

function sumBy(rows: readonly AdminDailyMetric[], pick: (row: AdminDailyMetric) => number) {
  return rows.reduce((total, row) => total + pick(row), 0);
}

function shortDay(day: string) {
  const date = new Date(`${day}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return day;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
}

function RevenueBars({ rows }: { rows: readonly AdminDailyMetric[] }) {
  const peak = rows.reduce((max, row) => Math.max(max, row.revenue_web_usd_minor), 0);
  const peakRow = rows.find((row) => row.revenue_web_usd_minor === peak && peak > 0);
  if (!rows.length) {
    return (
      <p className="py-10 text-center text-sm text-muted-foreground">
        No aggregate snapshots have been computed yet.
      </p>
    );
  }
  return (
    <>
      <div
        className="flex h-[150px] items-end gap-1.5 border-b"
        role="img"
        aria-label={
          peakRow
            ? `Daily web revenue, peak ${usd(peak)} on ${shortDay(peakRow.day)}`
            : "Daily web revenue, no revenue in this range"
        }
      >
        {rows.map((row) => {
          const height = peak > 0 ? Math.max(3, (row.revenue_web_usd_minor / peak) * 100) : 3;
          return (
            <span
              key={row.day}
              title={`${shortDay(row.day)}: ${usd(row.revenue_web_usd_minor)}`}
              className={`flex-1 rounded-t-[6px] ${
                row === peakRow ? "bg-primary" : "bg-primary/35"
              }`}
              style={{ height: `${height}%` }}
            />
          );
        })}
      </div>
      <div className="mt-2 flex justify-between text-xs text-muted-foreground">
        <span>{shortDay(rows[0]!.day)}</span>
        <span>{shortDay(rows.at(-1)!.day)}</span>
      </div>
    </>
  );
}

function LatestSignUps() {
  const [users, setUsers] = useState<AdminUser[] | null>(null);

  useEffect(() => {
    let cancelled = false;
    adminFoundationApi
      .listUsers({ sortBy: "created_at", sortOrder: "desc" })
      .then((result) => {
        if (!cancelled) setUsers(result.items.slice(0, 5));
      })
      // Roles without user search simply don't see this section.
      .catch(() => {
        if (!cancelled) setUsers([]);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (!users?.length) return null;

  return (
    <section className="mt-6" aria-labelledby="admin-latest-signups">
      <div className="mb-3 flex items-center justify-between">
        <h2 id="admin-latest-signups" className="text-[17px] font-bold tracking-[-.01em]">
          Latest sign-ups
        </h2>
        <Link to="/admin/users" className="text-sm font-bold text-accent-ink hover:underline">
          All users →
        </Link>
      </div>
      <AdminDataTable>
        <thead>
          <tr className="border-b">
            <th className="px-4 py-3">User</th>
            <th className="px-4 py-3">Signed up</th>
            <th className="px-4 py-3">Status</th>
            <th className="px-4 py-3 text-right">Balance</th>
            <th className="px-4 py-3">Latest purchase</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id} className="border-b last:border-0">
              <td className="px-4 py-3">
                <Link
                  to="/admin/users/$id"
                  params={{ id: user.id }}
                  className="flex items-center gap-2.5"
                >
                  <AvatarCircle initials={initials(user.display_name || user.email)} size="sm" />
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-bold">
                      {user.display_name || user.email}
                    </span>
                    <span className="block truncate text-xs text-muted-foreground">
                      {user.email}
                    </span>
                  </span>
                </Link>
              </td>
              <td className="px-4 py-3 text-muted-foreground">{dateTime(user.created_at)}</td>
              <td className="px-4 py-3">
                <AdminUserStatusBadge user={user} />
              </td>
              <td className="px-4 py-3 text-right font-mono">
                {user.cloud_minutes_available ?? 0} min
              </td>
              <td className="px-4 py-3">{user.latest_purchase_provider ?? "—"}</td>
            </tr>
          ))}
        </tbody>
      </AdminDataTable>
    </section>
  );
}

function OverviewBody() {
  const { identity } = useAuth();
  const allowed = ["owner", "admin", "finance"].includes(identity.role);
  const [data, setData] = useState<AdminOverview | null>(null);
  const [busy, setBusy] = useState(false);
  const [range, setRange] = useState<OverviewRange>(7);

  const load = async () => {
    if (!allowed) return;
    setBusy(true);
    try {
      setData(await adminD9Api.overview(30));
    } catch (error) {
      toast.error("Could not load overview", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
    // Role is stable for the authenticated admin session.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowed]);

  if (!allowed) {
    return (
      <PermissionPanel>
        Overview reporting metrics are available to Finance and Owner administrators.
      </PermissionPanel>
    );
  }

  const latest = data?.latest;
  const series = data?.series ?? [];
  const rangeRows = series.slice(-range);
  const previousRows = series.slice(-range * 2, -range);
  // Web-only product: PayPal web checkout is the only revenue channel shown.
  const rangeRevenue = sumBy(rangeRows, (row) => row.revenue_web_usd_minor);
  const previousRevenue = sumBy(previousRows, (row) => row.revenue_web_usd_minor);
  const rangeNewUsers = sumBy(rangeRows, (row) => row.new_users);
  const accountTotal = (latest?.free_users ?? 0) + (latest?.pro_users ?? 0);
  const proPercent =
    latest && accountTotal > 0 ? Math.round((latest.pro_users / accountTotal) * 100) : 0;
  const monthGross = data ? data.month_revenue_web_usd_minor : 0;
  const capacity =
    latest && latest.recording_capacity_limit
      ? latest.recording_running / latest.recording_capacity_limit
      : 0;
  const previous = series.at(-2);
  const errorRate =
    latest && latest.recording_total_24h > 0
      ? latest.recording_errors_24h / latest.recording_total_24h
      : 0;
  const previousErrorRate =
    previous && previous.recording_total_24h > 0
      ? previous.recording_errors_24h / previous.recording_total_24h
      : 0;
  const revenueChange =
    previousRows.length === range && previousRevenue > 0
      ? (rangeRevenue - previousRevenue) / previousRevenue
      : null;

  const exportReport = async (kind: "revenue" | "new-users" | "cloud-usage" | "recordings") => {
    try {
      const csv = await adminD9Api.exportReport(kind);
      downloadCsv(`savestream-${kind}.csv`, csv);
    } catch (error) {
      toast.error("Could not export report", {
        description: authErrorMessage(error),
      });
    }
  };

  const alerts: OverviewAlert[] = [];
  if (latest && latest.stuck_orders > 0) {
    alerts.push({
      key: "stuck",
      tone: "danger",
      title: `${latest.stuck_orders} payment ${latest.stuck_orders === 1 ? "order is" : "orders are"} stuck.`,
      message: "Paid in PayPal but credits not granted yet. Reconcile from Payments.",
      href: "/admin/payments",
      action: "Resolve",
    });
  }
  if (capacity >= 0.8) {
    alerts.push({
      key: "capacity",
      tone: "warning",
      title: `Recording capacity is at ${Math.round(capacity * 100)}%.`,
      message: `${latest?.recording_running ?? 0} running of ${latest?.recording_capacity_limit ?? 0} slots · ${latest?.recording_waiting ?? 0} waiting.`,
      href: "/admin/jobs",
      action: "View",
    });
  }
  if (latest && latest.recording_errors_24h > 0 && errorRate > previousErrorRate + 0.05) {
    alerts.push({
      key: "errors",
      tone: "warning",
      title: `Recording error rate increased to ${Math.round(errorRate * 100)}% in the last 24 hours.`,
      message: `${latest.recording_errors_24h} of ${latest.recording_total_24h} recordings failed.`,
      href: "/admin/jobs",
      action: "Jobs",
    });
  }
  if (latest && latest.open_complaints > 0) {
    alerts.push({
      key: "complaints",
      tone: "info",
      title: `${latest.open_complaints} complaint cases are still open.`,
      message: "Copyright and abuse reports waiting for review.",
      href: "/admin/safety",
      action: "Safety",
    });
  }

  return (
    <>
      <PageHeader
        title="Admin overview"
        subtitle={
          latest
            ? `Snapshot computed ${dateTime(latest.computed_at)} · UTC days, refreshed hourly`
            : "Precomputed daily business and operations snapshots."
        }
        action={
          <div className="flex flex-wrap items-center gap-2">
            <div
              className="inline-flex rounded-[12px] border bg-surface p-1"
              role="group"
              aria-label="Range"
            >
              {([7, 14, 30] as const).map((days) => (
                <button
                  key={days}
                  type="button"
                  aria-pressed={range === days}
                  onClick={() => setRange(days)}
                  className={`h-8 rounded-[9px] px-3 text-sm font-bold transition-colors ${
                    range === days
                      ? "bg-primary-subtle text-accent-ink"
                      : "text-muted-foreground hover:text-foreground"
                  }`}
                >
                  {days} d
                </button>
              ))}
            </div>
            <Button variant="outline" disabled={busy} onClick={() => void load()}>
              <RefreshCw className="size-4" />
              Refresh
            </Button>
          </div>
        }
      />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <AdminMetricCard
          label="Active users (7 d)"
          value={latest ? latest.active_users_weekly.toLocaleString("en-US") : "—"}
          detail={
            latest
              ? `DAU ${latest.active_users_daily} · MAU ${latest.active_users_monthly} · customer accounts only`
              : "Customer accounts only (admin, support and owner excluded)."
          }
        />
        <AdminMetricCard
          label={`Web (PayPal) revenue (${range} d)`}
          value={data ? usd(rangeRevenue) : "—"}
          detail={
            revenueChange === null
              ? `Month to date ${usd(monthGross)}`
              : `${revenueChange >= 0 ? "↑" : "↓"} ${Math.abs(Math.round(revenueChange * 1000) / 10)}% vs previous ${range} d`
          }
          tone={revenueChange === null ? undefined : revenueChange >= 0 ? "up" : "down"}
        />
        <AdminMetricCard
          label={`New users (${range} d)`}
          value={data ? rangeNewUsers.toLocaleString("en-US") : "—"}
          detail={latest ? `${latest.new_users} today` : undefined}
        />
        <AdminMetricCard
          label="Recording now"
          value={latest ? `${latest.recording_running} / ${latest.recording_waiting}` : "—"}
          detail={
            latest
              ? `running / waiting · ${Math.round(capacity * 100)}% of ${latest.recording_capacity_limit} slots`
              : undefined
          }
          tone={capacity >= 0.8 ? "down" : undefined}
        />
        <AdminMetricCard
          label="Failed recordings (24 h)"
          value={latest ? `${Math.round(errorRate * 1000) / 10}%` : "—"}
          detail={
            latest
              ? `${latest.recording_errors_24h} of ${latest.recording_total_24h} · rolling 24 h at snapshot time`
              : undefined
          }
          tone={latest && errorRate > previousErrorRate + 0.05 ? "down" : undefined}
        />
        <AdminMetricCard
          label="Accounts with purchases"
          value={latest ? latest.pro_users.toLocaleString("en-US") : "—"}
          detail={
            latest
              ? `${proPercent}% of ${accountTotal.toLocaleString("en-US")} accounts · ${latest.free_to_pro_weekly} first purchases (7 d)`
              : undefined
          }
        />
      </div>

      <div className="mt-6 flex flex-wrap items-start gap-5">
        <AdminCard
          className="min-w-0 flex-[1_1_420px]"
          bodyClassName=""
          title={
            <span className="flex items-center gap-2">
              Alerts
              {alerts.length ? <AdminBadge tone="danger">{alerts.length} open</AdminBadge> : null}
            </span>
          }
          action={
            <Link to="/admin/system" className="text-sm font-bold text-accent-ink hover:underline">
              System →
            </Link>
          }
        >
          {alerts.length ? (
            <ul>
              {alerts.map((alert) => (
                <li
                  key={alert.key}
                  className="flex items-start gap-3 border-b px-5 py-4 last:border-0"
                >
                  <span
                    className={`grid size-[34px] shrink-0 place-items-center rounded-[10px] ${alertTileTones[alert.tone]}`}
                  >
                    <AlertTriangle className="size-4" aria-hidden="true" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-sm font-bold">{alert.title}</span>
                    <span className="mt-0.5 block text-xs text-muted-foreground">
                      {alert.message}
                    </span>
                  </span>
                  <Button size="sm" variant="outline" asChild>
                    <a href={alert.href}>{alert.action}</a>
                  </Button>
                </li>
              ))}
            </ul>
          ) : (
            <div className="flex items-center gap-3 px-5 py-6 text-sm text-muted-foreground">
              <span className="grid size-[34px] place-items-center rounded-[10px] bg-success-subtle text-success">
                <CheckCircle2 className="size-4" aria-hidden="true" />
              </span>
              No dashboard alert thresholds are currently exceeded.
            </div>
          )}
        </AdminCard>

        <AdminCard
          className="min-w-0 flex-[1_1_420px]"
          title={`Revenue · Web (PayPal) · last ${range} days`}
          description="Gross USD before PayPal fees."
          action={
            <span className="font-mono text-lg font-bold">{data ? usd(rangeRevenue) : "—"}</span>
          }
        >
          <RevenueBars rows={rangeRows} />
          <dl className="mt-4 flex flex-wrap gap-x-6 gap-y-2 text-sm">
            <div className="flex gap-2">
              <dt className="text-muted-foreground">Today</dt>
              <dd className="font-mono font-bold">
                {latest ? usd(latest.revenue_web_usd_minor) : "—"}
              </dd>
            </div>
            <div className="flex gap-2">
              <dt className="text-muted-foreground">Month to date</dt>
              <dd className="font-mono font-bold">{data ? usd(monthGross) : "—"}</dd>
            </div>
          </dl>
        </AdminCard>
      </div>

      <LatestSignUps />

      <AdminCard
        className="mt-6"
        title="CSV reports"
        description="Exports default to the latest 30 days and are bounded to 366 days."
      >
        <div className="flex flex-wrap gap-2">
          {(
            [
              ["revenue", "Revenue"],
              ["new-users", "New users"],
              ["cloud-usage", "Cloud usage"],
              ["recordings", "Recordings by status"],
            ] as const
          ).map(([kind, label]) => (
            <Button key={kind} variant="outline" onClick={() => void exportReport(kind)}>
              <Download className="size-4" />
              {label}
            </Button>
          ))}
        </div>
      </AdminCard>

      <section className="mt-6" aria-labelledby="admin-snapshots">
        <h2 id="admin-snapshots" className="mb-3 text-[17px] font-bold tracking-[-.01em]">
          30-day snapshots
        </h2>
        <AdminDataTable>
          <thead>
            <tr className="border-b">
              <th className="px-4 py-3">Day</th>
              <th className="px-4 py-3 text-right">New users</th>
              <th className="px-4 py-3 text-right" title="Customer accounts only">
                DAU (customers)
              </th>
              <th className="px-4 py-3 text-right">With purchases</th>
              <th className="px-4 py-3 text-right">Web revenue (PayPal)</th>
            </tr>
          </thead>
          <tbody>
            {[...series].reverse().map((row) => (
              <tr key={row.day} className="border-b last:border-0">
                <td className="px-4 py-3">{row.day}</td>
                <td className="px-4 py-3 text-right font-mono">{row.new_users}</td>
                <td className="px-4 py-3 text-right font-mono">{row.active_users_daily}</td>
                <td className="px-4 py-3 text-right font-mono">{row.pro_users}</td>
                <td className="px-4 py-3 text-right font-mono">{usd(row.revenue_web_usd_minor)}</td>
              </tr>
            ))}
            {!series.length && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-sm text-muted-foreground">
                  {busy ? "Loading snapshots…" : "No aggregate snapshots have been computed yet."}
                </td>
              </tr>
            )}
          </tbody>
        </AdminDataTable>
      </section>
    </>
  );
}

function ReportDialog({
  report,
  onClose,
  onSaved,
}: {
  report: AdminSupportReport | null;
  onClose: () => void;
  onSaved: (report: AdminSupportReport) => void;
}) {
  const [status, setStatus] = useState<AdminSupportReport["status"]>("new");
  const [assignee, setAssignee] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!report) return;
    setStatus(report.status);
    setAssignee(report.assigned_to_user_id ?? "");
    setReason("");
  }, [report]);

  const save = async () => {
    if (!report) return;
    setBusy(true);
    try {
      const updated = await adminD9Api.updateSupportReport(
        report.id,
        status,
        assignee.trim() || null,
        reason.trim(),
      );
      onSaved(updated);
      toast.success("App report updated");
      onClose();
    } catch (error) {
      toast.error("Could not update app report", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={report !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[85vh] max-w-3xl overflow-y-auto">
        <DialogHeader>
          <DialogTitle>App report</DialogTitle>
          <DialogDescription>
            {report ? `${report.user_email} · ${dateTime(report.created_at)}` : "Loading…"}
          </DialogDescription>
        </DialogHeader>
        {report && (
          <div className="space-y-4">
            <div className="rounded-md border p-4 text-sm">
              <p>{report.description}</p>
              <div className="mt-3 grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
                <p>
                  User:{" "}
                  <a
                    className="underline underline-offset-2"
                    href={`/admin/users/${report.user_id}`}
                  >
                    {report.user_id}
                  </a>
                </p>
                <p>
                  Recording:{" "}
                  {report.recording_id ? (
                    <a
                      className="underline underline-offset-2"
                      href={`/admin/jobs/${report.recording_id}`}
                    >
                      {report.recording_id}
                    </a>
                  ) : (
                    "—"
                  )}
                </p>
                <p>Platform: {report.platform ?? "—"}</p>
                <p>App version: {report.app_version ?? "—"}</p>
                <p>Retained until: {dateTime(report.expires_at)}</p>
              </div>
            </div>
            <pre className="max-h-64 overflow-auto rounded-[12px] bg-[#15122B] p-3.5 font-mono text-xs leading-[1.65] text-[#D9D4F2]">
              {JSON.stringify(report.diagnostic_log, null, 2)}
            </pre>
            <div className="grid gap-3 sm:grid-cols-3">
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={status}
                onChange={(event) => setStatus(event.target.value as AdminSupportReport["status"])}
              >
                <option value="new">New</option>
                <option value="reviewing">Reviewing</option>
                <option value="resolved">Resolved</option>
                <option value="closed">Closed</option>
              </select>
              <Input
                placeholder="Assignee user ID"
                value={assignee}
                onChange={(event) => setAssignee(event.target.value)}
              />
              <Input
                placeholder="Reason"
                value={reason}
                onChange={(event) => setReason(event.target.value)}
              />
            </div>
          </div>
        )}
        <DialogFooter>
          <Button variant="outline" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button disabled={busy || reason.trim().length < 3} onClick={() => void save()}>
            {busy ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function reportTone(status: AdminSupportReport["status"]): AdminBadgeTone {
  if (status === "new") return "danger";
  if (status === "reviewing") return "warning";
  if (status === "resolved") return "success";
  return "neutral";
}

function ReportsBody() {
  const { identity } = useAuth();
  const allowed = ["owner", "admin", "support"].includes(identity.role);
  const [reports, setReports] = useState<AdminSupportReport[]>([]);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("");
  const [sortOrder, setSortOrder] = useState<"asc" | "desc">("desc");
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<AdminSupportReport | null>(null);

  const load = async (cursor?: string | null) => {
    if (!allowed) return;
    setBusy(true);
    try {
      const result = await adminD9Api.listSupportReports({
        cursor: cursor ?? null,
        query: query.trim() || undefined,
        status: status || undefined,
        sortOrder,
      });
      setReports(result.items);
      setNextCursor(result.next_cursor);
      setHasMore(result.has_more);
    } catch (error) {
      toast.error("Could not load app reports", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
    // Filters are applied explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowed]);

  const exportCsv = async () => {
    try {
      const csv = await adminD9Api.exportSupportReports({
        query: query.trim() || undefined,
        status: status || undefined,
        sortOrder,
      });
      downloadCsv("savestream-app-reports.csv", csv);
    } catch (error) {
      toast.error("Could not export app reports", {
        description: authErrorMessage(error),
      });
    }
  };

  if (!allowed) {
    return (
      <PermissionPanel>
        App reports are available to Support and Owner administrators.
      </PermissionPanel>
    );
  }

  return (
    <>
      <PageHeader
        title="Problem reports"
        subtitle="In-app bug reports and diagnostics retained for 180 days. Video payloads are rejected."
        action={
          <Button variant="outline" disabled={busy} onClick={() => void load()}>
            <RefreshCw className="mr-2 size-4" />
            Refresh
          </Button>
        }
      />
      <div className="mb-4 grid gap-3 rounded-[16px] border bg-surface p-4 md:grid-cols-5">
        <Input
          placeholder="Search email or description"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <select
          className="h-9 rounded-md border bg-background px-3 text-sm"
          value={status}
          onChange={(event) => setStatus(event.target.value)}
        >
          <option value="">All statuses</option>
          <option value="new">New</option>
          <option value="reviewing">Reviewing</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>
        <select
          className="h-9 rounded-md border bg-background px-3 text-sm"
          value={sortOrder}
          onChange={(event) => setSortOrder(event.target.value as "asc" | "desc")}
        >
          <option value="desc">Newest first</option>
          <option value="asc">Oldest first</option>
        </select>
        <Button onClick={() => void load(null)}>Apply filters</Button>
        <Button variant="outline" onClick={() => void exportCsv()}>
          <Download className="mr-2 size-4" />
          CSV
        </Button>
      </div>

      <div className="mt-4">
        <AdminDataTable>
          <thead>
            <tr className="border-b">
              <th className="px-4 py-3">User</th>
              <th className="px-4 py-3">Description</th>
              <th className="px-4 py-3">Recording</th>
              <th className="px-4 py-3">App</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report) => (
              <tr key={report.id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <p className="font-bold">{report.user_email}</p>
                  <p className="text-xs text-muted-foreground">{dateTime(report.created_at)}</p>
                </td>
                <td className="max-w-md truncate px-4 py-3 text-sm">{report.description}</td>
                <td className="px-4 py-3 font-mono text-xs">
                  {report.recording_id ? (
                    <a
                      className="text-accent-ink hover:underline"
                      href={`/admin/jobs/${report.recording_id}`}
                    >
                      {report.recording_id.slice(0, 8)}
                    </a>
                  ) : (
                    "—"
                  )}
                </td>
                <td className="px-4 py-3 text-xs text-muted-foreground">
                  {report.platform ?? "—"} {report.app_version ?? ""}
                </td>
                <td className="px-4 py-3">
                  <AdminBadge tone={reportTone(report.status)} dot>
                    {report.status}
                  </AdminBadge>
                </td>
                <td className="px-4 py-3 text-right">
                  <Button size="sm" onClick={() => setSelected(report)}>
                    Review
                  </Button>
                </td>
              </tr>
            ))}
            {!reports.length && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-sm text-muted-foreground">
                  {busy ? "Loading app reports…" : "No app reports match the current filters."}
                </td>
              </tr>
            )}
          </tbody>
        </AdminDataTable>
      </div>

      {hasMore && nextCursor && (
        <div className="mt-4">
          <Button variant="outline" onClick={() => void load(nextCursor)} disabled={busy}>
            Next page
          </Button>
        </div>
      )}

      <ReportDialog
        report={selected}
        onClose={() => setSelected(null)}
        onSaved={(updated) =>
          setReports((current) => current.map((item) => (item.id === updated.id ? updated : item)))
        }
      />
    </>
  );
}

export function AdminOverviewD9Page() {
  return (
    <AdminMfaGate>
      <AppShell>
        <OverviewBody />
      </AppShell>
    </AdminMfaGate>
  );
}

export function AdminReportsD9Page() {
  return (
    <AdminMfaGate>
      <AppShell>
        <ReportsBody />
      </AppShell>
    </AdminMfaGate>
  );
}
