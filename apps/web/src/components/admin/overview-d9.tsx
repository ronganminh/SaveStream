import { useEffect, useState } from "react";
import { RefreshCw } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, PageHeader } from "@/components/app-components";
import {
  AdminDataTable,
  AdminMfaGate,
  AdminMetricCard,
} from "@/components/admin/foundation";
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
  type AdminOverview,
  type AdminSupportReport,
} from "@/repositories/admin-api";

function usd(minor: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(minor / 100);
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString("en-US") : "—";
}

function PermissionPanel({ children }: { children: string }) {
  return (
    <div className="rounded-lg border bg-background p-6">
      <h2 className="font-medium">Permission required</h2>
      <p className="mt-2 text-sm text-muted-foreground">{children}</p>
    </div>
  );
}

function OverviewBody() {
  const { identity } = useAuth();
  const allowed = ["owner", "admin", "finance"].includes(identity.role);
  const [data, setData] = useState<AdminOverview | null>(null);
  const [busy, setBusy] = useState(false);

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
  const gross =
    (latest?.revenue_web_usd_minor ?? 0) +
    (latest?.revenue_app_store_usd_minor ?? 0) +
    (latest?.revenue_google_play_usd_minor ?? 0);
  const capacity =
    latest && latest.recording_capacity_limit
      ? latest.recording_running / latest.recording_capacity_limit
      : 0;

  const alerts = [
    capacity >= 0.8
      ? `Recording capacity is at ${Math.round(capacity * 100)}%.`
      : null,
    latest && latest.recording_errors_24h > 0
      ? `${latest.recording_errors_24h} recording errors in the last 24 hours.`
      : null,
    latest && latest.stuck_orders > 0
      ? `${latest.stuck_orders} payment orders are stuck.`
      : null,
    latest && latest.open_complaints > 0
      ? `${latest.open_complaints} complaint cases are still open.`
      : null,
  ].filter((item): item is string => item !== null);

  return (
    <>
      <PageHeader
        title="Overview"
        subtitle="Precomputed daily business and operations snapshots."
        action={
          <Button variant="outline" disabled={busy} onClick={() => void load()}>
            <RefreshCw className="mr-2 size-4" />
            Refresh
          </Button>
        }
      />
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <AdminMetricCard label="New users" value={latest?.new_users ?? "—"} />
        <AdminMetricCard
          label="DAU / WAU / MAU"
          value={
            latest
              ? `${latest.active_users_daily} / ${latest.active_users_weekly} / ${latest.active_users_monthly}`
              : "—"
          }
        />
        <AdminMetricCard
          label="Free / Pro"
          value={latest ? `${latest.free_users} / ${latest.pro_users}` : "—"}
        />
        <AdminMetricCard
          label="Free → Pro"
          value={latest?.free_to_pro_users ?? "—"}
        />
        <AdminMetricCard
          label="Gross revenue"
          value={latest ? usd(gross) : "—"}
        />
        <AdminMetricCard
          label="Running / waiting"
          value={
            latest
              ? `${latest.recording_running} / ${latest.recording_waiting}`
              : "—"
          }
        />
        <AdminMetricCard
          label="Recording errors (24h)"
          value={latest?.recording_errors_24h ?? "—"}
        />
        <AdminMetricCard
          label="Computed"
          value={dateTime(latest?.computed_at)}
        />
      </div>

      <section className="mt-6 rounded-lg border bg-background p-5">
        <h2 className="font-medium">Alerts</h2>
        <div className="mt-3 space-y-2 text-sm">
          {alerts.map((alert) => (
            <div key={alert} className="rounded-md border p-3">
              {alert}
            </div>
          ))}
          {!alerts.length && (
            <p className="text-muted-foreground">
              No dashboard alert thresholds are currently exceeded.
            </p>
          )}
        </div>
      </section>

      <section className="mt-6 rounded-lg border bg-background">
        <div className="border-b p-5">
          <h2 className="font-medium">Revenue by channel</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Gross USD before fees. Store fees are estimated separately in finance reports.
          </p>
        </div>
        <div className="grid gap-3 p-5 md:grid-cols-3">
          <AdminMetricCard
            label="Web"
            value={latest ? usd(latest.revenue_web_usd_minor) : "—"}
          />
          <AdminMetricCard
            label="App Store"
            value={latest ? usd(latest.revenue_app_store_usd_minor) : "—"}
          />
          <AdminMetricCard
            label="Google Play"
            value={latest ? usd(latest.revenue_google_play_usd_minor) : "—"}
          />
        </div>
      </section>

      <section className="mt-6 rounded-lg border bg-background">
        <div className="border-b p-5">
          <h2 className="font-medium">30-day snapshots</h2>
        </div>
        <AdminDataTable>
          <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
            <tr>
              <th className="px-4 py-3">Day</th>
              <th className="px-4 py-3">New users</th>
              <th className="px-4 py-3">DAU</th>
              <th className="px-4 py-3">Pro</th>
              <th className="px-4 py-3">Gross revenue</th>
            </tr>
          </thead>
          <tbody>
            {(data?.series ?? []).map((row) => (
              <tr key={row.day} className="border-b last:border-0">
                <td className="px-4 py-3">{row.day}</td>
                <td className="px-4 py-3">{row.new_users}</td>
                <td className="px-4 py-3">{row.active_users_daily}</td>
                <td className="px-4 py-3">{row.pro_users}</td>
                <td className="px-4 py-3">
                  {usd(
                    row.revenue_web_usd_minor +
                      row.revenue_app_store_usd_minor +
                      row.revenue_google_play_usd_minor,
                  )}
                </td>
              </tr>
            ))}
            {!data?.series.length && (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-8 text-center text-sm text-muted-foreground"
                >
                  {busy
                    ? "Loading snapshots…"
                    : "No aggregate snapshots have been computed yet."}
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
  const [status, setStatus] =
    useState<AdminSupportReport["status"]>("new");
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
            {report
              ? `${report.user_email} · ${dateTime(report.created_at)}`
              : "Loading…"}
          </DialogDescription>
        </DialogHeader>
        {report && (
          <div className="space-y-4">
            <div className="rounded-md border p-4 text-sm">
              <p>{report.description}</p>
              <div className="mt-3 grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
                <p>User: {report.user_id}</p>
                <p>Recording: {report.recording_id ?? "—"}</p>
                <p>Platform: {report.platform ?? "—"}</p>
                <p>App version: {report.app_version ?? "—"}</p>
                <p>Retained until: {dateTime(report.expires_at)}</p>
              </div>
            </div>
            <pre className="max-h-64 overflow-auto rounded-md border bg-muted/30 p-3 text-xs">
              {JSON.stringify(report.diagnostic_log, null, 2)}
            </pre>
            <div className="grid gap-3 sm:grid-cols-3">
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={status}
                onChange={(event) =>
                  setStatus(event.target.value as AdminSupportReport["status"])
                }
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
          <Button
            disabled={busy || reason.trim().length < 3}
            onClick={() => void save()}
          >
            {busy ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function ReportsBody() {
  const { identity } = useAuth();
  const allowed = ["owner", "admin", "support"].includes(identity.role);
  const [reports, setReports] = useState<AdminSupportReport[]>([]);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<AdminSupportReport | null>(null);

  const load = async () => {
    if (!allowed) return;
    setBusy(true);
    try {
      const result = await adminD9Api.listSupportReports({
        query: query.trim() || undefined,
        status: status || undefined,
      });
      setReports(result.items);
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
        title="App reports"
        subtitle="In-app bug reports and diagnostics retained for 180 days. Video payloads are rejected."
        action={
          <Button variant="outline" disabled={busy} onClick={() => void load()}>
            <RefreshCw className="mr-2 size-4" />
            Refresh
          </Button>
        }
      />
      <div className="grid gap-3 rounded-lg border bg-background p-4 md:grid-cols-3">
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
        <Button onClick={() => void load()}>Apply filters</Button>
      </div>

      <div className="mt-4">
        <AdminDataTable>
          <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
            <tr>
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
                <td className="px-4 py-3 text-sm">{report.user_email}</td>
                <td className="max-w-md truncate px-4 py-3 text-sm">
                  {report.description}
                </td>
                <td className="px-4 py-3 text-xs">
                  {report.recording_id ?? "—"}
                </td>
                <td className="px-4 py-3 text-xs">
                  {report.platform ?? "—"} {report.app_version ?? ""}
                </td>
                <td className="px-4 py-3 text-sm">{report.status}</td>
                <td className="px-4 py-3 text-right">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => setSelected(report)}
                  >
                    Review
                  </Button>
                </td>
              </tr>
            ))}
            {!reports.length && (
              <tr>
                <td
                  colSpan={6}
                  className="px-4 py-8 text-center text-sm text-muted-foreground"
                >
                  {busy
                    ? "Loading app reports…"
                    : "No app reports match the current filters."}
                </td>
              </tr>
            )}
          </tbody>
        </AdminDataTable>
      </div>

      <ReportDialog
        report={selected}
        onClose={() => setSelected(null)}
        onSaved={(updated) =>
          setReports((current) =>
            current.map((item) => (item.id === updated.id ? updated : item)),
          )
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
