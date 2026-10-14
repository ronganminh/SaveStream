import { formatAdminDateTime } from "@/lib/formatters";
import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Download,
  ExternalLink,
  MoreHorizontal,
  RefreshCw,
  RotateCcw,
  Square,
  Trash2,
} from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import type { RecordingResponse } from "@/api/types";
import { AppShell, AvatarCircle, PageHeader } from "@/components/app-components";
import { initials } from "@/repositories/mappers/channel";
import {
  AdminBadge,
  AdminCard,
  AdminDataTable,
  AdminMetricCard,
  type AdminBadgeTone,
} from "@/components/admin/foundation";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  adminFoundationApi,
  adminRecordingOpsApi,
  type AdminCapacity,
  type AdminDetectorMetrics,
  type AdminQueue,
  type AdminRecordingFilters,
  type AdminWatchChannel,
} from "@/repositories/admin-api";

function dateTime(value: string | null | undefined) {
  return formatAdminDateTime(value);
}

function channelLabel(recording: RecordingResponse) {
  return recording.creator?.username ?? recording.source.value;
}

const tabTriggerClass =
  "-mb-px h-11 flex-none rounded-none border-b-2 border-transparent bg-transparent px-3 font-bold text-muted-foreground shadow-none data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:text-foreground data-[state=active]:shadow-none";

const statusChips = [
  ["", "All"],
  ["recording", "Recording"],
  ["processing", "Processing"],
  ["uploading", "Uploading"],
  ["waiting_for_cloud_slot", "Waiting for slot"],
  ["failed", "Failed"],
  ["completed", "Completed"],
] as const;

function statusTone(status: string): AdminBadgeTone {
  if (status === "completed") return "success";
  if (status === "failed" || status === "missed_no_cloud_slot") return "danger";
  if (status === "recording") return "info";
  if (status === "processing" || status === "uploading") return "accent";
  if (status === "stopped") return "neutral";
  return "warning";
}

function statusDot(status: string) {
  return {
    success: "bg-success",
    danger: "bg-destructive",
    info: "bg-info",
    accent: "bg-primary",
    neutral: "bg-muted-foreground",
    warning: "bg-warning",
  }[statusTone(status)];
}

function duration(seconds: number) {
  if (!seconds) return "—";
  const total = Math.round(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return h
    ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
    : `${m}:${String(s).padStart(2, "0")}`;
}

function bytes(value: number) {
  if (!value) return "—";
  if (value >= 1024 ** 3) return `${(value / 1024 ** 3).toFixed(1)} GB`;
  return `${Math.max(1, Math.round(value / 1024 ** 2))} MB`;
}

function downloadText(filename: string, content: string) {
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

type PendingAction = {
  title: string;
  description: string;
  requiresStepUp?: boolean;
  retention?: boolean;
  run: (reason: string, token: string | null, expiresAt: string | null) => Promise<void>;
};

function ActionDialog({ action, onClose }: { action: PendingAction | null; onClose: () => void }) {
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [expiresAt, setExpiresAt] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!action) return;
    setReason("");
    setPassword("");
    setTotp("");
    setExpiresAt("");
  }, [action]);

  const confirm = async () => {
    if (!action) return;
    setBusy(true);
    try {
      const token = action.requiresStepUp
        ? (await adminFoundationApi.stepUp(password, totp)).token
        : null;
      await action.run(reason.trim(), token, expiresAt || null);
      onClose();
    } catch (error) {
      toast.error("Action failed", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  const valid =
    reason.trim().length >= 3 &&
    (!action?.requiresStepUp || (password.length > 0 && totp.trim().length === 6)) &&
    (!action?.retention || Boolean(expiresAt));

  return (
    <Dialog open={action !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{action?.title ?? "Confirm action"}</DialogTitle>
          <DialogDescription>{action?.description}</DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          {action?.retention && (
            <Input
              type="datetime-local"
              aria-label="New retention expiry"
              value={expiresAt}
              onChange={(event) => setExpiresAt(event.target.value)}
            />
          )}
          <Input
            placeholder="Reason"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          />
          {action?.requiresStepUp && (
            <>
              <Input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
              <Input
                inputMode="numeric"
                placeholder="Authenticator code"
                value={totp}
                maxLength={6}
                onChange={(event) => setTotp(event.target.value)}
              />
            </>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button disabled={busy || !valid} onClick={() => void confirm()}>
            {busy ? "Confirming…" : "Confirm"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function CapacityChart({ capacity }: { capacity: AdminCapacity | null }) {
  if (!capacity?.hourly.length) {
    return (
      <p className="text-sm text-muted-foreground">No recording history in the last 7 days.</p>
    );
  }
  return (
    <div>
      <div className="flex h-36 min-w-[900px] items-end gap-px rounded-[12px] bg-surface-2/60 p-3">
        {capacity.hourly.map((point) => {
          const height = Math.max(2, Math.min(100, (point.max_concurrent / point.limit) * 100));
          return (
            <div
              key={point.hour}
              className="min-w-1 flex-1 rounded-t-sm bg-primary"
              style={{ height: `${height}%` }}
              title={`${dateTime(point.hour)} · ${point.max_concurrent}/${point.limit}`}
            />
          );
        })}
      </div>
      <p className="mt-2 text-xs text-muted-foreground">
        Hourly peak concurrent cloud recordings across the last 7 days.
      </p>
    </div>
  );
}

function DetectorChart({ detector }: { detector: AdminDetectorMetrics | null }) {
  if (!detector?.hourly.length) {
    return <p className="text-sm text-muted-foreground">No detector telemetry yet.</p>;
  }
  // Scaled to the worst hour so small failure rates stay visible.
  const peak = Math.max(...detector.hourly.map((hour) => hour.failure_rate ?? 0), 0.01);
  return (
    <div className="flex h-24 items-end gap-1 rounded-[12px] bg-surface-2/60 p-3">
      {detector.hourly.map((point) => {
        const height =
          point.failure_rate === null ? 2 : Math.max(4, (point.failure_rate / peak) * 100);
        return (
          <div
            key={point.hour}
            className={`flex-1 rounded-t-[4px] ${(point.failure_rate ?? 0) > 0.1 ? "bg-warning" : "bg-primary/60"}`}
            style={{ height: `${height}%` }}
            title={`${dateTime(point.hour)} · ${point.failures}/${point.checks} failed`}
          />
        );
      })}
    </div>
  );
}

export function AdminRecordingOperationsPage() {
  const [recordings, setRecordings] = useState<RecordingResponse[]>([]);
  const [recordingCursor, setRecordingCursor] = useState<string | null>(null);
  const [recordingHasMore, setRecordingHasMore] = useState(false);
  const [filters, setFilters] = useState<AdminRecordingFilters>({ sortOrder: "desc" });
  const [queue, setQueue] = useState<AdminQueue | null>(null);
  const [channels, setChannels] = useState<AdminWatchChannel[]>([]);
  const [detector, setDetector] = useState<AdminDetectorMetrics | null>(null);
  const [capacity, setCapacity] = useState<AdminCapacity | null>(null);
  const [busy, setBusy] = useState(true);
  const [action, setAction] = useState<PendingAction | null>(null);

  const loadRecordings = async (cursor?: string | null) => {
    const result = await adminRecordingOpsApi.listRecordings({
      ...filters,
      cursor: cursor ?? null,
    });
    setRecordings(result.items);
    setRecordingCursor(result.pagination.next_cursor);
    setRecordingHasMore(result.pagination.has_more);
  };

  const applyStatus = (status: string) => {
    const next: AdminRecordingFilters = { ...filters, status };
    setFilters(next);
    void adminRecordingOpsApi
      .listRecordings({ ...next, cursor: null })
      .then((result) => {
        setRecordings(result.items);
        setRecordingCursor(result.pagination.next_cursor);
        setRecordingHasMore(result.pagination.has_more);
      })
      .catch((error) =>
        toast.error("Could not load recordings", { description: authErrorMessage(error) }),
      );
  };

  const loadAll = async () => {
    setBusy(true);
    try {
      const [recordingResult, queueResult, channelResult, detectorResult, capacityResult] =
        await Promise.all([
          adminRecordingOpsApi.listRecordings(filters),
          adminRecordingOpsApi.queue(),
          adminRecordingOpsApi.watchChannels(),
          adminRecordingOpsApi.detectorMetrics(),
          adminRecordingOpsApi.capacity(),
        ]);
      setRecordings(recordingResult.items);
      setRecordingCursor(recordingResult.pagination.next_cursor);
      setRecordingHasMore(recordingResult.pagination.has_more);
      setQueue(queueResult);
      setChannels(channelResult.items);
      setDetector(detectorResult);
      setCapacity(capacityResult);
    } catch (error) {
      toast.error("Could not load recording operations", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void loadAll();
    // Filters are applied explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const statuses = useMemo(
    () => [
      "queued",
      "resolving",
      "waiting_live",
      "recording",
      "processing",
      "uploading",
      "completed",
      "failed",
      "stop_requested",
      "stopped",
      "waiting_for_cloud_slot",
      "missed_no_cloud_slot",
    ],
    [],
  );

  const refreshAfterMutation = async () => {
    await loadAll();
  };

  const exportCsv = async () => {
    try {
      downloadText(
        "savestream-admin-recordings.csv",
        await adminRecordingOpsApi.exportRecordings(filters),
      );
    } catch (error) {
      toast.error("Recording export failed", { description: authErrorMessage(error) });
    }
  };

  const detectorDegraded = (detector?.failure_rate_1h ?? 0) > 0.1;
  const inUse = capacity?.current_in_use ?? 0;
  const limit = capacity?.global_limit ?? 6;
  const usedShare = limit > 0 ? Math.min(1, inUse / limit) : 0;
  const recordingNow = recordings.filter((recording) => recording.status === "recording").length;

  return (
    <AppShell>
      <PageHeader
        title="Recordings & LIVE operations"
        subtitle={
          capacity
            ? `${inUse} of ${limit} recording streams in use · ${channels.length} watched channels`
            : "Cloud recordings, watched channels, LIVE detector health, queue pressure, and global capacity."
        }
        action={
          <Button variant="outline" onClick={() => void loadAll()}>
            <RefreshCw className="size-4" />
            Refresh
          </Button>
        }
      />

      <div className="mb-5 flex flex-wrap gap-5">
        <AdminCard
          className="min-w-0 flex-[2_1_520px]"
          title="LIVE detector health"
          action={
            detector ? (
              <AdminBadge tone={detectorDegraded ? "warning" : "success"} dot>
                {detectorDegraded ? "Degraded" : "Healthy"}
              </AdminBadge>
            ) : null
          }
        >
          <dl className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
            {[
              ["Last run", detector?.last_run_at ? dateTime(detector.last_run_at) : "—"],
              [
                "Last latency",
                detector?.last_latency_ms == null ? "—" : `${detector.last_latency_ms} ms`,
              ],
              [
                "1h average",
                detector?.average_latency_ms_1h == null
                  ? "—"
                  : `${detector.average_latency_ms_1h} ms`,
              ],
              [
                "1h failure rate",
                detector?.failure_rate_1h == null
                  ? "—"
                  : `${(detector.failure_rate_1h * 100).toFixed(1)}%`,
              ],
            ].map(([label, value]) => (
              <div key={label}>
                <dt className="text-xs font-semibold text-muted-foreground">{label}</dt>
                <dd className="mt-0.5 font-mono text-sm font-bold">{value}</dd>
              </div>
            ))}
          </dl>
          <DetectorChart detector={detector} />
        </AdminCard>

        <AdminCard className="min-w-0 flex-[1_1_300px]" title="Recorder capacity">
          <div className="flex justify-between text-sm">
            <span className="font-semibold text-muted-foreground">Streams in use</span>
            <span className="font-mono font-bold">
              {inUse} / {limit}
            </span>
          </div>
          <div className="mt-2 h-2.5 overflow-hidden rounded-full bg-surface-2">
            <div
              className={`h-full rounded-full ${usedShare >= 0.85 ? "bg-warning" : "bg-primary"}`}
              style={{ width: `${usedShare * 100}%` }}
            />
          </div>
          <p className="mt-1.5 text-xs text-muted-foreground">
            Global stream limit is read-only infrastructure capacity.
          </p>
          <dl className="mt-4 space-y-2 border-t pt-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Waiting for cloud slot</dt>
              <dd className="font-mono font-bold">{queue?.items.length ?? 0}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Missed today</dt>
              <dd className="font-mono font-bold">{queue?.missed_today ?? 0}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Stuck processing / uploading</dt>
              <dd
                className={`font-mono font-bold ${capacity?.stuck_uploads.length ? "text-warning-foreground" : ""}`}
              >
                {capacity?.stuck_uploads.length ?? 0}
              </dd>
            </div>
          </dl>
        </AdminCard>
      </div>

      {!!capacity?.stuck_uploads.length && (
        <div
          role="alert"
          className="mb-5 flex gap-3 rounded-[14px] border border-warning/40 bg-warning-subtle p-4 text-sm"
        >
          <AlertTriangle className="mt-0.5 size-4 flex-none text-warning" />
          <div className="space-y-1">
            <p className="font-semibold">
              {capacity.stuck_uploads.length === 1
                ? "1 recording is"
                : `${capacity.stuck_uploads.length} recordings are`}{" "}
              stuck processing or uploading (over{" "}
              {Math.round(capacity.stuck_upload_after_seconds / 60)} minutes).
            </p>
            <ul className="space-y-0.5 text-muted-foreground">
              {capacity.stuck_uploads.map((item) => (
                <li key={item.recording_id}>
                  @{item.channel.replace(/^@/, "")} · {item.status} since{" "}
                  {formatAdminDateTime(item.since)} · {Math.round(item.bytes_recorded / 1048576)}{" "}
                  MiB ·{" "}
                  <a
                    className="font-mono text-xs text-accent-ink hover:underline"
                    href={`/admin/jobs/${item.recording_id}`}
                  >
                    {item.recording_id}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      <Tabs defaultValue="recordings" className="space-y-5">
        <TabsList className="h-auto w-full flex-wrap justify-start gap-1 rounded-none border-b bg-transparent p-0">
          {(
            [
              ["recordings", "Recording jobs"],
              ["queue", `Queue · ${queue?.items.length ?? 0}`],
              ["channels", `Channels · ${channels.length}`],
              ["detector", "LIVE detector"],
              ["capacity", "Capacity"],
            ] as const
          ).map(([value, label]) => (
            <TabsTrigger key={value} value={value} className={tabTriggerClass}>
              {label}
            </TabsTrigger>
          ))}
        </TabsList>

        <TabsContent value="recordings" className="space-y-4">
          <div className="flex flex-wrap gap-2" role="group" aria-label="Job status">
            {statusChips.map(([value, label]) => {
              const on = (filters.status ?? "") === value;
              return (
                <button
                  key={value || "all"}
                  type="button"
                  aria-pressed={on}
                  onClick={() => applyStatus(value)}
                  className={`inline-flex h-[34px] items-center gap-2 rounded-full border px-3.5 text-sm font-bold transition-colors ${
                    on
                      ? "border-primary bg-primary-subtle text-accent-ink"
                      : "bg-surface text-muted-foreground hover:text-foreground"
                  }`}
                >
                  {value ? <span className={`size-2 rounded-full ${statusDot(value)}`} /> : null}
                  {label}
                  {value === "recording" && recordingNow ? (
                    <span className="font-mono text-xs">{recordingNow}</span>
                  ) : null}
                </button>
              );
            })}
          </div>
          <div className="grid gap-3 rounded-[16px] border bg-surface p-4 md:grid-cols-4">
            <Input
              placeholder="User ID"
              value={filters.userId ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, userId: event.target.value }))
              }
            />
            <Input
              placeholder="Channel / source"
              value={filters.channel ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, channel: event.target.value }))
              }
            />
            <select
              className="h-9 rounded-md border bg-background px-3 text-sm"
              value={filters.status ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, status: event.target.value }))
              }
            >
              <option value="">All statuses</option>
              {statuses.map((status) => (
                <option key={status} value={status}>
                  {status}
                </option>
              ))}
            </select>
            <select
              className="h-9 rounded-md border bg-background px-3 text-sm"
              value={filters.sortOrder ?? "desc"}
              onChange={(event) =>
                setFilters((current) => ({
                  ...current,
                  sortOrder: event.target.value as "asc" | "desc",
                }))
              }
            >
              <option value="desc">Newest first</option>
              <option value="asc">Oldest first</option>
            </select>
            <Input
              type="datetime-local"
              value={filters.createdFrom ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, createdFrom: event.target.value }))
              }
            />
            <Input
              type="datetime-local"
              value={filters.createdTo ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, createdTo: event.target.value }))
              }
            />
            <div className="flex gap-2 md:col-span-2">
              <Button onClick={() => void loadRecordings(null)}>Apply filters</Button>
              <Button variant="outline" onClick={() => void exportCsv()}>
                <Download className="mr-2 size-4" />
                Export CSV
              </Button>
            </div>
          </div>

          <AdminDataTable>
            <thead>
              <tr className="border-b">
                <th className="px-4 py-3">Job</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3 text-right">Duration</th>
                <th className="px-4 py-3 text-right">Size</th>
                <th className="px-4 py-3 text-right">Charged</th>
                <th className="px-4 py-3">Expires</th>
                <th className="px-4 py-3">Created</th>
                <th className="px-4 py-3 text-right">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {recordings.map((recording) => (
                <tr key={recording.id} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <AvatarCircle
                        src={recording.creator?.avatar_url}
                        initials={initials(channelLabel(recording).replace(/^@/, ""))}
                        size="sm"
                      />
                      <div className="min-w-0">
                        <p className="font-bold">{channelLabel(recording)}</p>
                        <a
                          href={`/admin/jobs/${recording.id}`}
                          className="block max-w-[220px] truncate font-mono text-xs text-accent-ink hover:underline"
                        >
                          {recording.id}
                        </a>
                      </div>
                    </div>
                  </td>
                  <td className="max-w-xs px-4 py-3">
                    <AdminBadge tone={statusTone(recording.status)} dot>
                      {recording.status.replaceAll("_", " ")}
                      {recording.queue_position ? ` #${recording.queue_position}` : ""}
                    </AdminBadge>
                    {recording.error ? (
                      <span
                        className="mt-1 block text-xs text-destructive"
                        title={recording.error.message}
                      >
                        <span className="font-mono">{recording.error.code}</span>
                        <span className="block truncate text-muted-foreground">
                          {recording.error.message}
                        </span>
                      </span>
                    ) : null}
                  </td>
                  <td className="px-4 py-3 text-right font-mono">
                    {duration(recording.duration_seconds)}
                  </td>
                  <td className="px-4 py-3 text-right font-mono">
                    {bytes(recording.bytes_recorded)}
                  </td>
                  <td className="px-4 py-3 text-right font-mono">
                    {recording.minutes_charged ?? 0} min
                  </td>
                  <td className="px-4 py-3 text-xs text-muted-foreground">
                    {dateTime(recording.expires_at)}
                  </td>
                  <td className="px-4 py-3 text-xs text-muted-foreground">
                    {dateTime(recording.created_at)}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-1.5">
                      {recording.actions.can_stop && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            setAction({
                              title: "Stop recording",
                              description:
                                "Stop this cloud recording and record the reason in the audit log.",
                              run: async (reason) => {
                                await adminRecordingOpsApi.stop(recording.id, reason);
                                await refreshAfterMutation();
                              },
                            })
                          }
                        >
                          <Square className="size-3" />
                          Stop
                        </Button>
                      )}
                      {recording.actions.can_retry && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            void adminRecordingOpsApi
                              .retry(recording.id)
                              .then(refreshAfterMutation)
                              .catch((error) =>
                                toast.error("Retry failed", {
                                  description: authErrorMessage(error),
                                }),
                              )
                          }
                        >
                          <RotateCcw className="size-3" />
                          Retry
                        </Button>
                      )}
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            size="sm"
                            variant="ghost"
                            aria-label={`More actions for ${recording.id}`}
                          >
                            <MoreHorizontal className="size-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem asChild>
                            <a href={`/admin/jobs/${recording.id}`}>Open job detail</a>
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onSelect={() =>
                              setAction({
                                title: "Extend retention",
                                description:
                                  "Choose a new expiry and record why this recording needs longer retention.",
                                retention: true,
                                run: async (reason, _token, expiresAt) => {
                                  if (!expiresAt) return;
                                  await adminRecordingOpsApi.extendRetention(
                                    recording.id,
                                    expiresAt,
                                    reason,
                                  );
                                  await refreshAfterMutation();
                                },
                              })
                            }
                          >
                            Retention
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onSelect={() =>
                              setAction({
                                title: "Request playback access",
                                description:
                                  "This sensitive read requires step-up authentication and is written to the audit log.",
                                requiresStepUp: true,
                                run: async (reason, token) => {
                                  if (!token) return;
                                  const access = await adminRecordingOpsApi.requestPlayback(
                                    recording.id,
                                    reason,
                                    token,
                                  );
                                  window.open(access.url, "_blank", "noopener,noreferrer");
                                },
                              })
                            }
                          >
                            <ExternalLink className="size-3.5" />
                            Playback
                          </DropdownMenuItem>
                          {recording.actions.can_delete && (
                            <DropdownMenuItem
                              className="text-destructive focus:text-destructive"
                              onSelect={() =>
                                setAction({
                                  title: "Delete recording",
                                  description:
                                    "Delete the recording and schedule stored artifacts for cleanup. This requires step-up authentication.",
                                  requiresStepUp: true,
                                  run: async (reason, token) => {
                                    if (!token) return;
                                    await adminRecordingOpsApi.delete(recording.id, reason, token);
                                    await refreshAfterMutation();
                                  },
                                })
                              }
                            >
                              <Trash2 className="size-3.5" />
                              Delete
                            </DropdownMenuItem>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </td>
                </tr>
              ))}
              {!recordings.length && (
                <tr>
                  <td colSpan={8} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    {busy ? "Loading recordings…" : "No recordings match the current filters."}
                  </td>
                </tr>
              )}
            </tbody>
          </AdminDataTable>
          {recordingHasMore && recordingCursor && (
            <Button variant="outline" onClick={() => void loadRecordings(recordingCursor)}>
              Next page
            </Button>
          )}
        </TabsContent>

        <TabsContent value="queue" className="space-y-4">
          <div className="grid gap-3 md:grid-cols-2">
            <AdminMetricCard label="Waiting for cloud slot" value={queue?.items.length ?? 0} />
            <AdminMetricCard label="Missed today" value={queue?.missed_today ?? 0} />
          </div>
          <AdminDataTable>
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
                <th className="px-4 py-3">Position</th>
                <th className="px-4 py-3">User</th>
                <th className="px-4 py-3">Channel</th>
                <th className="px-4 py-3">Waiting since</th>
              </tr>
            </thead>
            <tbody>
              {queue?.items.map((item) => (
                <tr key={item.recording_id} className="border-b last:border-0">
                  <td className="px-4 py-3 font-medium">#{item.queue_position}</td>
                  <td className="px-4 py-3">
                    <p>{item.user_email}</p>
                    <p className="text-xs text-muted-foreground">{item.user_id}</p>
                  </td>
                  <td className="px-4 py-3">{item.channel}</td>
                  <td className="px-4 py-3 text-xs">{dateTime(item.waiting_since)}</td>
                </tr>
              ))}
            </tbody>
          </AdminDataTable>
        </TabsContent>

        <TabsContent value="channels" className="space-y-4">
          <AdminDataTable>
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
                <th className="px-4 py-3">Channel</th>
                <th className="px-4 py-3">Followers</th>
                <th className="px-4 py-3">Auto-record</th>
                <th className="px-4 py-3">Paused</th>
                <th className="px-4 py-3">Failing</th>
                <th className="px-4 py-3">Last check</th>
                <th className="px-4 py-3">Last error</th>
              </tr>
            </thead>
            <tbody>
              {channels.map((channel) => (
                <tr
                  key={`${channel.source_type}:${channel.channel}`}
                  className="border-b last:border-0"
                >
                  <td className="px-4 py-3 font-medium">{channel.channel}</td>
                  <td className="px-4 py-3">{channel.followers}</td>
                  <td className="px-4 py-3">{channel.auto_record_count}</td>
                  <td className="px-4 py-3">{channel.paused_count}</td>
                  <td className="px-4 py-3">
                    {channel.failing_count} · max streak {channel.max_failure_count}
                  </td>
                  <td className="px-4 py-3 text-xs">{dateTime(channel.last_checked_at)}</td>
                  <td className="max-w-xs truncate px-4 py-3 text-xs">
                    {channel.last_error ?? "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </AdminDataTable>
        </TabsContent>

        <TabsContent value="detector" className="space-y-4">
          <div className="grid gap-3 md:grid-cols-4">
            <AdminMetricCard label="Last run" value={dateTime(detector?.last_run_at)} />
            <AdminMetricCard
              label="Last latency"
              value={
                detector?.last_latency_ms === null || detector?.last_latency_ms === undefined
                  ? "—"
                  : `${detector.last_latency_ms} ms`
              }
            />
            <AdminMetricCard
              label="1h average latency"
              value={
                detector?.average_latency_ms_1h === null ||
                detector?.average_latency_ms_1h === undefined
                  ? "—"
                  : `${detector.average_latency_ms_1h} ms`
              }
            />
            <AdminMetricCard
              label="1h failure rate"
              value={
                detector?.failure_rate_1h === null || detector?.failure_rate_1h === undefined
                  ? "—"
                  : `${(detector.failure_rate_1h * 100).toFixed(1)}%`
              }
            />
          </div>
          <section className="rounded-[16px] border bg-surface p-4">
            <h2 className="font-medium">Hourly detector failure rate</h2>
            <p className="mb-4 mt-1 text-sm text-muted-foreground">
              24-hour check telemetry. Taller bars mean a higher failure rate.
            </p>
            <DetectorChart detector={detector} />
          </section>
        </TabsContent>

        <TabsContent value="capacity" className="space-y-4">
          <div className="grid gap-3 md:grid-cols-2">
            <AdminMetricCard
              label="Recording streams in use"
              value={`${capacity?.current_in_use ?? 0} / ${capacity?.global_limit ?? 6}`}
            />
            <AdminMetricCard
              label="Available global streams"
              value={Math.max((capacity?.global_limit ?? 6) - (capacity?.current_in_use ?? 0), 0)}
            />
          </div>
          <section className="overflow-x-auto rounded-[16px] border bg-surface p-4">
            <h2 className="font-medium">7-day hourly capacity</h2>
            <p className="mb-4 mt-1 text-sm text-muted-foreground">
              Read-only infrastructure capacity. The global stream limit is not editable from Admin.
            </p>
            <CapacityChart capacity={capacity} />
          </section>
        </TabsContent>
      </Tabs>

      <ActionDialog action={action} onClose={() => setAction(null)} />
    </AppShell>
  );
}
