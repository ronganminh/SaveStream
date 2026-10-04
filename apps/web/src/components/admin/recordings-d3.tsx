import { useEffect, useMemo, useState } from "react";
import { Download, ExternalLink, RefreshCw, RotateCcw, Square, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import type { RecordingResponse } from "@/api/types";
import { AppShell, PageHeader } from "@/components/app-components";
import { AdminDataTable, AdminMetricCard } from "@/components/admin/foundation";
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
  return value ? new Date(value).toLocaleString("en-US") : "—";
}

function channelLabel(recording: RecordingResponse) {
  return recording.creator?.username ?? recording.source.value;
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

function ActionDialog({
  action,
  onClose,
}: {
  action: PendingAction | null;
  onClose: () => void;
}) {
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
    return <p className="text-sm text-muted-foreground">No recording history in the last 7 days.</p>;
  }
  return (
    <div>
      <div className="flex h-36 min-w-[900px] items-end gap-px rounded-lg border bg-muted/20 p-3">
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
  return (
    <div className="flex h-28 items-end gap-1 rounded-lg border bg-muted/20 p-3">
      {detector.hourly.map((point) => {
        const height = point.failure_rate === null ? 2 : Math.max(2, point.failure_rate * 100);
        return (
          <div
            key={point.hour}
            className="flex-1 rounded-t-sm bg-primary"
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

  return (
    <AppShell>
      <PageHeader
        title="Recordings & LIVE operations"
        subtitle="Cloud recordings, watched channels, LIVE detector health, queue pressure, and global capacity."
        action={
          <Button variant="outline" onClick={() => void loadAll()}>
            <RefreshCw className="mr-2 size-4" />
            Refresh
          </Button>
        }
      />

      <Tabs defaultValue="recordings" className="space-y-5">
        <TabsList className="flex flex-wrap">
          <TabsTrigger value="recordings">Recordings</TabsTrigger>
          <TabsTrigger value="queue">Queue</TabsTrigger>
          <TabsTrigger value="channels">Channels</TabsTrigger>
          <TabsTrigger value="detector">LIVE detector</TabsTrigger>
          <TabsTrigger value="capacity">Capacity</TabsTrigger>
        </TabsList>

        <TabsContent value="recordings" className="space-y-4">
          <div className="grid gap-3 rounded-lg border bg-background p-4 md:grid-cols-4">
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
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
                <th className="px-4 py-3">Channel</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Queue</th>
                <th className="px-4 py-3">Charged</th>
                <th className="px-4 py-3">Expires</th>
                <th className="px-4 py-3">Created</th>
                <th className="px-4 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {recordings.map((recording) => (
                <tr key={recording.id} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <p className="font-medium">{channelLabel(recording)}</p>
                    <p className="text-xs text-muted-foreground">{recording.id}</p>
                  </td>
                  <td className="px-4 py-3">{recording.status}</td>
                  <td className="px-4 py-3">{recording.queue_position ?? "—"}</td>
                  <td className="px-4 py-3">{recording.minutes_charged} min</td>
                  <td className="px-4 py-3 text-xs">{dateTime(recording.expires_at)}</td>
                  <td className="px-4 py-3 text-xs">{dateTime(recording.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap justify-end gap-2">
                      {recording.actions.can_stop && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            setAction({
                              title: "Stop recording",
                              description: "Stop this cloud recording and record the reason in the audit log.",
                              run: async (reason) => {
                                await adminRecordingOpsApi.stop(recording.id, reason);
                                await refreshAfterMutation();
                              },
                            })
                          }
                        >
                          <Square className="mr-1 size-3" />
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
                          <RotateCcw className="mr-1 size-3" />
                          Retry
                        </Button>
                      )}
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() =>
                          setAction({
                            title: "Extend retention",
                            description: "Choose a new expiry and record why this recording needs longer retention.",
                            retention: true,
                            run: async (reason, _token, expiresAt) => {
                              if (!expiresAt) return;
                              await adminRecordingOpsApi.extendRetention(recording.id, expiresAt, reason);
                              await refreshAfterMutation();
                            },
                          })
                        }
                      >
                        Retention
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() =>
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
                        <ExternalLink className="mr-1 size-3" />
                        Playback
                      </Button>
                      {recording.actions.can_delete && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
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
                          <Trash2 className="mr-1 size-3" />
                          Delete
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {!recordings.length && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-sm text-muted-foreground">
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
                <tr key={`${channel.source_type}:${channel.channel}`} className="border-b last:border-0">
                  <td className="px-4 py-3 font-medium">{channel.channel}</td>
                  <td className="px-4 py-3">{channel.followers}</td>
                  <td className="px-4 py-3">{channel.auto_record_count}</td>
                  <td className="px-4 py-3">{channel.paused_count}</td>
                  <td className="px-4 py-3">
                    {channel.failing_count} · max streak {channel.max_failure_count}
                  </td>
                  <td className="px-4 py-3 text-xs">{dateTime(channel.last_checked_at)}</td>
                  <td className="max-w-xs truncate px-4 py-3 text-xs">{channel.last_error ?? "—"}</td>
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
              value={detector?.last_latency_ms === null || detector?.last_latency_ms === undefined ? "—" : `${detector.last_latency_ms} ms`}
            />
            <AdminMetricCard
              label="1h average latency"
              value={detector?.average_latency_ms_1h === null || detector?.average_latency_ms_1h === undefined ? "—" : `${detector.average_latency_ms_1h} ms`}
            />
            <AdminMetricCard
              label="1h failure rate"
              value={detector?.failure_rate_1h === null || detector?.failure_rate_1h === undefined ? "—" : `${(detector.failure_rate_1h * 100).toFixed(1)}%`}
            />
          </div>
          <section className="rounded-lg border bg-background p-4">
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
          <section className="overflow-x-auto rounded-lg border bg-background p-4">
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
