import { formatAdminDateTime } from "@/lib/formatters";
import { useEffect, useMemo, useState } from "react";
import {
  Ban,
  Download,
  ExternalLink,
  Plus,
  RefreshCw,
  ShieldAlert,
  Trash2,
  Unlock,
} from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, PageHeader } from "@/components/app-components";
import {
  AdminBadge,
  AdminDataTable,
  AdminMetricCard,
  AdminTabsList,
  AdminTabsTrigger,
  type AdminBadgeTone,
} from "@/components/admin/foundation";
import {
  ChannelAccountBlockDialog,
  ChannelAccountBlocksTable,
  type ChannelAccountBlockAction,
} from "@/components/admin/channel-account-blocks";
import { VideoDownloaderAdminTab } from "@/components/admin/video-downloader-admin";
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
import { Tabs, TabsContent } from "@/components/ui/tabs";
import {
  adminFoundationApi,
  adminSafetyApi,
  type AdminChannelAccountBlock,
  type AdminComplaint,
  type AdminComplaintFilters,
  type AdminCreatorBlock,
  type AdminSuspiciousAccount,
} from "@/repositories/admin-api";
import type { WatchResponse } from "@/api/types";

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

function CreateComplaintDialog({
  open,
  onClose,
  onCreated,
}: {
  open: boolean;
  onClose: () => void;
  onCreated: (complaint: AdminComplaint) => void;
}) {
  const [kind, setKind] = useState<"copyright" | "abuse">("copyright");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [sourceType, setSourceType] = useState<"username" | "room_id" | "url">("username");
  const [sourceValue, setSourceValue] = useState("");
  const [recordingId, setRecordingId] = useState("");
  const [summary, setSummary] = useState("");
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!open) return;
    setKind("copyright");
    setName("");
    setEmail("");
    setSourceType("username");
    setSourceValue("");
    setRecordingId("");
    setSummary("");
    setBody("");
  }, [open]);

  const submit = async () => {
    setBusy(true);
    try {
      const complaint = await adminSafetyApi.createComplaint({
        kind,
        complainant_name: name.trim(),
        complainant_email: email.trim(),
        channel_source_type: sourceValue.trim() ? sourceType : null,
        channel_source_value: sourceValue.trim() || null,
        recording_id: recordingId.trim() || null,
        summary: summary.trim(),
        body: body.trim(),
      });
      onCreated(complaint);
      toast.success("Complaint case created");
      onClose();
    } catch (error) {
      toast.error("Could not create complaint", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  const valid =
    name.trim().length > 0 &&
    email.trim().length >= 3 &&
    summary.trim().length >= 3 &&
    body.trim().length >= 3 &&
    (sourceValue.trim().length > 0 || recordingId.trim().length > 0);

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Create complaint case</DialogTitle>
          <DialogDescription>
            Manually create a copyright or abuse case from an external report such as abuse@ email.
          </DialogDescription>
        </DialogHeader>
        <div className="grid gap-3 sm:grid-cols-2">
          <select
            className="h-9 rounded-md border bg-background px-3 text-sm"
            value={kind}
            onChange={(event) => setKind(event.target.value as "copyright" | "abuse")}
          >
            <option value="copyright">Copyright</option>
            <option value="abuse">Abuse</option>
          </select>
          <Input
            placeholder="Complainant name"
            value={name}
            onChange={(event) => setName(event.target.value)}
          />
          <Input
            placeholder="Complainant email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />
          <Input
            placeholder="Recording ID (optional)"
            value={recordingId}
            onChange={(event) => setRecordingId(event.target.value)}
          />
          <select
            className="h-9 rounded-md border bg-background px-3 text-sm"
            value={sourceType}
            onChange={(event) =>
              setSourceType(event.target.value as "username" | "room_id" | "url")
            }
          >
            <option value="username">Username</option>
            <option value="room_id">Room ID</option>
            <option value="url">URL</option>
          </select>
          <Input
            placeholder="Channel / source value"
            value={sourceValue}
            onChange={(event) => setSourceValue(event.target.value)}
          />
          <Input
            className="sm:col-span-2"
            placeholder="Summary"
            value={summary}
            onChange={(event) => setSummary(event.target.value)}
          />
          <textarea
            className="min-h-28 rounded-md border bg-background px-3 py-2 text-sm sm:col-span-2"
            placeholder="Complaint details"
            value={body}
            onChange={(event) => setBody(event.target.value)}
          />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button onClick={() => void submit()} disabled={!valid || busy}>
            {busy ? "Creating…" : "Create case"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function normalizeChannel(value: string | null | undefined) {
  return (value ?? "")
    .trim()
    .replace(/^https?:\/\/(www\.)?tiktok\.com\//i, "")
    .replace(/^@/, "")
    .replace(/[/?#].*$/, "")
    .toLowerCase();
}

/** From a complaint: find the reported channel on one account and block it
 * for that account only (complaint ID prefilled). */
function BlockForAccountFromComplaint({
  complaint,
  onBlock,
}: {
  complaint: AdminComplaint;
  onBlock: (action: ChannelAccountBlockAction) => void;
}) {
  const [userId, setUserId] = useState("");
  const [busy, setBusy] = useState(false);
  const [found, setFound] = useState<{ email: string; watches: WatchResponse[] } | null>(null);
  const channel = normalizeChannel(complaint.channel_source_value);

  useEffect(() => {
    setUserId("");
    setFound(null);
  }, [complaint.id]);

  const find = async () => {
    setBusy(true);
    try {
      const detail = await adminFoundationApi.getUserDetail(userId.trim());
      setFound({
        email: detail.user.email,
        watches: detail.watches.filter(
          (watch) =>
            !channel ||
            normalizeChannel(watch.creator?.username) === channel ||
            normalizeChannel(watch.source.value) === channel,
        ),
      });
    } catch (error) {
      setFound(null);
      toast.error("Could not load the account", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-3 rounded-lg border p-4">
      <div>
        <h3 className="font-medium">Block for one account</h3>
        <p className="text-xs text-muted-foreground">
          Stops only that account from recording {channel ? `@${channel}` : "the channel"}. Other
          accounts are not affected. Use Block (creator) to stop everyone.
        </p>
      </div>
      <div className="flex gap-2">
        <Input
          placeholder="Account user ID"
          value={userId}
          onChange={(event) => setUserId(event.target.value)}
        />
        <Button variant="outline" disabled={busy || !userId.trim()} onClick={() => void find()}>
          {busy ? "Finding…" : "Find channel"}
        </Button>
      </div>
      {found && (
        <div className="space-y-2">
          {found.watches.map((watch) => {
            const name = `@${(watch.creator?.username ?? watch.source.value).replace(/^@/, "")}`;
            return (
              <div
                key={watch.id}
                className="flex items-center justify-between gap-3 rounded-md border px-3 py-2 text-sm"
              >
                <span>
                  <b>{name}</b>{" "}
                  <span className="text-xs text-muted-foreground">on {found.email}</span>
                </span>
                {watch.blocked ? (
                  <span className="text-xs font-bold text-destructive">Already blocked</span>
                ) : (
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      onBlock({
                        mode: "block",
                        watchId: watch.id,
                        channel: name,
                        account: found.email,
                        complaintId: complaint.id,
                      })
                    }
                  >
                    <Ban className="size-3" />
                    Block for this account
                  </Button>
                )}
              </div>
            );
          })}
          {!found.watches.length && (
            <p className="text-sm text-muted-foreground">
              {found.email} has no channel matching {channel ? `@${channel}` : "this complaint"}.
            </p>
          )}
        </div>
      )}
    </div>
  );
}

function ComplaintDetailDialog({
  complaint,
  onClose,
  onUpdated,
  onBlockForAccount,
}: {
  complaint: AdminComplaint | null;
  onClose: () => void;
  onUpdated: (complaint: AdminComplaint) => void;
  onBlockForAccount: (action: ChannelAccountBlockAction) => void;
}) {
  const [full, setFull] = useState<AdminComplaint | null>(null);
  const [status, setStatus] = useState<AdminComplaint["status"]>("new");
  const [assignee, setAssignee] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!complaint) {
      setFull(null);
      return;
    }
    setFull(complaint);
    setStatus(complaint.status);
    setAssignee(complaint.assigned_to_user_id ?? "");
    setReason("");
    void adminSafetyApi
      .getComplaint(complaint.id)
      .then((result) => {
        setFull(result);
        setStatus(result.status);
        setAssignee(result.assigned_to_user_id ?? "");
      })
      .catch((error) =>
        toast.error("Could not load complaint timeline", {
          description: authErrorMessage(error),
        }),
      );
  }, [complaint]);

  const update = async () => {
    if (!full) return;
    setBusy(true);
    try {
      const result = await adminSafetyApi.updateComplaint(
        full.id,
        status,
        assignee.trim() || null,
        reason.trim(),
      );
      setFull(result);
      onUpdated(result);
      setReason("");
      toast.success("Complaint case updated");
    } catch (error) {
      toast.error("Could not update complaint", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={complaint !== null} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="max-h-[85vh] max-w-3xl overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{full?.summary ?? "Complaint case"}</DialogTitle>
          <DialogDescription>
            {full
              ? `${full.kind} · ${full.complainant_email} · ${dateTime(full.created_at)}`
              : "Loading…"}
          </DialogDescription>
        </DialogHeader>

        {full && (
          <div className="space-y-5">
            <div className="rounded-lg border bg-muted/20 p-4 text-sm">
              <p>{full.body}</p>
              <div className="mt-3 grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
                <p>Channel: {full.channel_source_value ?? "—"}</p>
                <p>Recording: {full.recording_id ?? "—"}</p>
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={status}
                onChange={(event) => setStatus(event.target.value as AdminComplaint["status"])}
              >
                <option value="new">New</option>
                <option value="reviewing">Reviewing</option>
                <option value="resolved">Resolved</option>
                <option value="rejected">Rejected</option>
              </select>
              <Input
                placeholder="Assignee user ID (optional)"
                value={assignee}
                onChange={(event) => setAssignee(event.target.value)}
              />
              <Input
                placeholder="Reason for change"
                value={reason}
                onChange={(event) => setReason(event.target.value)}
              />
            </div>
            <Button disabled={busy || reason.trim().length < 3} onClick={() => void update()}>
              {busy ? "Saving…" : "Update case"}
            </Button>

            {full.channel_source_value && (
              <BlockForAccountFromComplaint complaint={full} onBlock={onBlockForAccount} />
            )}

            <div>
              <h3 className="mb-2 font-medium">Timeline</h3>
              <div className="space-y-2">
                {full.timeline.map((event) => (
                  <div key={event.id} className="rounded-md border p-3 text-sm">
                    <div className="flex justify-between gap-3">
                      <span className="font-medium">{event.action}</span>
                      <span className="text-xs text-muted-foreground">
                        {dateTime(event.created_at)}
                      </span>
                    </div>
                    {event.note && <p className="mt-1 text-muted-foreground">{event.note}</p>}
                  </div>
                ))}
                {!full.timeline.length && (
                  <p className="text-sm text-muted-foreground">No timeline events yet.</p>
                )}
              </div>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

type SafetyAction =
  | { mode: "block"; complaint?: AdminComplaint | null }
  | { mode: "unblock"; block: AdminCreatorBlock }
  | { mode: "delete"; block: AdminCreatorBlock };

function SafetyActionDialog({
  action,
  onClose,
  onDone,
}: {
  action: SafetyAction | null;
  onClose: () => void;
  onDone: () => Promise<void>;
}) {
  const [sourceType, setSourceType] = useState<"username" | "room_id" | "url">("username");
  const [sourceValue, setSourceValue] = useState("");
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!action) return;
    const complaint = action.mode === "block" ? action.complaint : null;
    setSourceType(
      complaint?.channel_source_type === "room_id" || complaint?.channel_source_type === "url"
        ? complaint.channel_source_type
        : "username",
    );
    setSourceValue(complaint?.channel_source_value ?? "");
    setReason("");
    setPassword("");
    setTotp("");
  }, [action]);

  const submit = async () => {
    if (!action) return;
    setBusy(true);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      if (action.mode === "block") {
        await adminSafetyApi.blockCreator(
          {
            source_type: sourceType,
            source_value: sourceValue.trim(),
            complaint_id: action.complaint?.id ?? null,
            reason: reason.trim(),
          },
          stepUp.token,
        );
      } else if (action.mode === "unblock") {
        await adminSafetyApi.unblockCreator(action.block.id, reason.trim(), stepUp.token);
      } else {
        const result = await adminSafetyApi.deleteBlockedRecordings(
          action.block.id,
          reason.trim(),
          stepUp.token,
        );
        toast.success("Deletion review action submitted", {
          description: `${result.deleted_recording_ids.length} deleted, ${result.pending_stop_recording_ids.length} waiting to stop.`,
        });
      }
      if (action.mode !== "delete") {
        toast.success(action.mode === "block" ? "Creator blocked" : "Creator unblocked");
      }
      await onDone();
      onClose();
    } catch (error) {
      toast.error("Safety action failed", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  const blockMode = action?.mode === "block";
  const valid =
    reason.trim().length >= 3 &&
    password.length > 0 &&
    totp.trim().length === 6 &&
    (!blockMode || sourceValue.trim().length > 0);

  const title =
    action?.mode === "block"
      ? "Block creator globally"
      : action?.mode === "unblock"
        ? "Unblock creator"
        : "Delete locked recordings";

  return (
    <Dialog open={action !== null} onOpenChange={(next) => !next && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>
            This dangerous action requires password re-entry, an authenticator code, a reason, and
            is permanently audited.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          {blockMode && (
            <>
              <select
                className="h-9 w-full rounded-md border bg-background px-3 text-sm"
                value={sourceType}
                onChange={(event) =>
                  setSourceType(event.target.value as "username" | "room_id" | "url")
                }
              >
                <option value="username">Username</option>
                <option value="room_id">Room ID</option>
                <option value="url">URL</option>
              </select>
              <Input
                placeholder="Creator source"
                value={sourceValue}
                onChange={(event) => setSourceValue(event.target.value)}
              />
            </>
          )}
          <Input
            placeholder="Reason"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          />
          <Input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <Input
            inputMode="numeric"
            maxLength={6}
            placeholder="Authenticator code"
            value={totp}
            onChange={(event) => setTotp(event.target.value)}
          />
        </div>
        <DialogFooter>
          <Button variant="outline" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button disabled={!valid || busy} onClick={() => void submit()}>
            {busy ? "Confirming…" : "Confirm"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function caseTone(status: string): AdminBadgeTone {
  if (status === "new") return "danger";
  if (status === "reviewing") return "warning";
  if (status === "resolved") return "success";
  return "neutral";
}

export function AdminSafetyD8Page() {
  const { identity } = useAuth();
  const canUseSafety = ["owner", "admin", "support"].includes(identity.role);
  const [filters, setFilters] = useState<AdminComplaintFilters>({});
  const [complaints, setComplaints] = useState<AdminComplaint[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [blocks, setBlocks] = useState<AdminCreatorBlock[]>([]);
  const [channelBlocks, setChannelBlocks] = useState<AdminChannelAccountBlock[]>([]);
  const [channelBlockAction, setChannelBlockAction] = useState<ChannelAccountBlockAction | null>(
    null,
  );
  const [suspicious, setSuspicious] = useState<AdminSuspiciousAccount[]>([]);
  const [busy, setBusy] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);
  const [selectedComplaint, setSelectedComplaint] = useState<AdminComplaint | null>(null);
  const [action, setAction] = useState<SafetyAction | null>(null);

  const loadComplaints = async (cursor?: string | null) => {
    const result = await adminSafetyApi.listComplaints({
      ...filters,
      cursor: cursor ?? null,
    });
    setComplaints(result.items);
    setNextCursor(result.next_cursor);
    setHasMore(result.has_more);
  };

  const load = async () => {
    if (!canUseSafety) {
      setBusy(false);
      return;
    }
    setBusy(true);
    try {
      const [complaintResult, blockResult, channelBlockResult, suspiciousResult] =
        await Promise.all([
          adminSafetyApi.listComplaints(filters),
          adminSafetyApi.listCreatorBlocks(true),
          adminSafetyApi.listChannelAccountBlocks({ activeOnly: true }),
          adminSafetyApi.suspiciousAccounts(),
        ]);
      setComplaints(complaintResult.items);
      setNextCursor(complaintResult.next_cursor);
      setHasMore(complaintResult.has_more);
      setBlocks(blockResult.items);
      setChannelBlocks(channelBlockResult.items);
      setSuspicious(suspiciousResult.items);
    } catch (error) {
      toast.error("Could not load Safety", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
    // Filters are applied explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canUseSafety]);

  const counts = useMemo(
    () => ({
      open: complaints.filter((item) => item.status === "new" || item.status === "reviewing")
        .length,
      blocks: blocks.length,
      channelBlocks: channelBlocks.length,
      suspicious: suspicious.length,
    }),
    [blocks.length, channelBlocks.length, complaints, suspicious.length],
  );

  const exportCsv = async () => {
    try {
      const content = await adminSafetyApi.exportComplaints(filters);
      downloadCsv("savestream-complaints.csv", content);
    } catch (error) {
      toast.error("Complaint export failed", { description: authErrorMessage(error) });
    }
  };

  if (!canUseSafety) {
    return (
      <AppShell>
        <PageHeader title="Safety" subtitle="Complaint and creator-safety operations." />
        <div className="rounded-[16px] border bg-surface p-6">
          <h2 className="font-medium">Permission required</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Safety cases are available to Support and Owner administrators.
          </p>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell>
      <PageHeader
        title="Safety"
        subtitle="Review copyright and abuse reports, creator restrictions, and suspicious account signals."
        action={
          <div className="flex gap-2">
            <Button variant="outline" disabled={busy} onClick={() => void load()}>
              <RefreshCw className="size-4" />
              Refresh
            </Button>
            <Button onClick={() => setCreateOpen(true)}>
              <Plus className="size-4" />
              Create complaint
            </Button>
          </div>
        }
      />

      <div className="grid gap-3 md:grid-cols-3">
        <AdminMetricCard label="Open complaint cases" value={counts.open} />
        <AdminMetricCard label="Active creator blocks" value={counts.blocks} />
        <AdminMetricCard label="Suspicious accounts" value={counts.suspicious} />
      </div>

      <Tabs defaultValue="complaints" className="mt-6 space-y-5">
        <AdminTabsList label="Safety sections">
          <AdminTabsTrigger value="complaints" count={counts.open}>
            Complaints
          </AdminTabsTrigger>
          <AdminTabsTrigger value="blocks" count={counts.blocks}>
            Creator blocks
          </AdminTabsTrigger>
          <AdminTabsTrigger value="channel-blocks" count={counts.channelBlocks}>
            Account channel blocks
          </AdminTabsTrigger>
          <AdminTabsTrigger value="suspicious" count={counts.suspicious}>
            Suspicious accounts
          </AdminTabsTrigger>
          <AdminTabsTrigger value="downloader">Downloader</AdminTabsTrigger>
        </AdminTabsList>

        <TabsContent value="complaints" className="space-y-4">
          <div className="grid gap-3 rounded-[16px] border bg-surface p-4 md:grid-cols-4">
            <Input
              placeholder="Search email, summary, channel"
              value={filters.query ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, query: event.target.value }))
              }
            />
            <select
              className="h-9 rounded-md border bg-background px-3 text-sm"
              value={filters.kind ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, kind: event.target.value }))
              }
            >
              <option value="">All kinds</option>
              <option value="copyright">Copyright</option>
              <option value="abuse">Abuse</option>
            </select>
            <select
              className="h-9 rounded-md border bg-background px-3 text-sm"
              value={filters.status ?? ""}
              onChange={(event) =>
                setFilters((current) => ({ ...current, status: event.target.value }))
              }
            >
              <option value="">All statuses</option>
              <option value="new">New</option>
              <option value="reviewing">Reviewing</option>
              <option value="resolved">Resolved</option>
              <option value="rejected">Rejected</option>
            </select>
            <div className="flex gap-2">
              <Button onClick={() => void loadComplaints(null)}>Apply</Button>
              <Button variant="outline" onClick={() => void exportCsv()}>
                <Download className="size-4" />
                CSV
              </Button>
            </div>
          </div>

          <AdminDataTable>
            <thead>
              <tr className="border-b">
                <th className="px-4 py-3">Case</th>
                <th className="px-4 py-3">Target</th>
                <th className="px-4 py-3">Complainant</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Created</th>
                <th className="px-4 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {complaints.map((item) => (
                <tr key={item.id} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <p className="font-bold">{item.summary}</p>
                    <p className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                      <AdminBadge tone={item.kind === "copyright" ? "accent" : "danger"}>
                        {item.kind}
                      </AdminBadge>
                      <span className="font-mono">{item.id}</span>
                    </p>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {item.channel_source_value ?? item.recording_id ?? "—"}
                  </td>
                  <td className="px-4 py-3 text-sm">{item.complainant_email}</td>
                  <td className="px-4 py-3">
                    <AdminBadge tone={caseTone(item.status)} dot>
                      {item.status}
                    </AdminBadge>
                  </td>
                  <td className="px-4 py-3 text-xs">{dateTime(item.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button size="sm" onClick={() => setSelectedComplaint(item)}>
                        <ExternalLink className="size-3" />
                        Review
                      </Button>
                      {item.channel_source_value && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setAction({ mode: "block", complaint: item })}
                        >
                          <ShieldAlert className="size-3" />
                          Block
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {!complaints.length && (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    {busy ? "Loading complaints…" : "No complaint cases match the current filters."}
                  </td>
                </tr>
              )}
            </tbody>
          </AdminDataTable>
          {hasMore && nextCursor && (
            <Button variant="outline" onClick={() => void loadComplaints(nextCursor)}>
              Next page
            </Button>
          )}
        </TabsContent>

        <TabsContent value="blocks" className="space-y-4">
          <div className="flex justify-end">
            <Button onClick={() => setAction({ mode: "block", complaint: null })}>
              <ShieldAlert className="size-4" />
              Block creator
            </Button>
          </div>
          <AdminDataTable>
            <thead>
              <tr className="border-b">
                <th className="px-4 py-3">Creator</th>
                <th className="px-4 py-3">Reason</th>
                <th className="px-4 py-3">Complaint</th>
                <th className="px-4 py-3">Blocked</th>
                <th className="px-4 py-3 text-right">Review outcome</th>
              </tr>
            </thead>
            <tbody>
              {blocks.map((block) => (
                <tr key={block.id} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <p className="font-bold">{block.source_value}</p>
                    <p className="text-xs text-muted-foreground">{block.source_type}</p>
                  </td>
                  <td className="max-w-sm truncate px-4 py-3 text-sm">{block.reason}</td>
                  <td className="px-4 py-3 text-xs">{block.complaint_id ?? "—"}</td>
                  <td className="px-4 py-3 text-xs">{dateTime(block.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setAction({ mode: "delete", block })}
                      >
                        <Trash2 className="size-3" />
                        Delete recordings
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setAction({ mode: "unblock", block })}
                      >
                        <Unlock className="size-3" />
                        Unblock
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
              {!blocks.length && (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    No active creator blocks.
                  </td>
                </tr>
              )}
            </tbody>
          </AdminDataTable>
          <p className="text-xs text-muted-foreground">
            Deleting locked recordings never issues an automatic credit refund. Use Payments for any
            manual refund or credit adjustment.
          </p>
        </TabsContent>

        <TabsContent value="channel-blocks" className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Channels stopped for one account after a report. Other accounts can still record the
            channel. To add one, open the user’s Channels tab (or a complaint) and choose Block for
            this account.
          </p>
          <ChannelAccountBlocksTable
            blocks={channelBlocks}
            busy={busy}
            onUnblock={(block) => setChannelBlockAction({ mode: "unblock", block })}
          />
        </TabsContent>

        <TabsContent value="suspicious">
          <AdminDataTable>
            <thead>
              <tr className="border-b">
                <th className="px-4 py-3">Account</th>
                <th className="px-4 py-3">Signals</th>
                <th className="px-4 py-3">Rate limits (24h)</th>
                <th className="px-4 py-3">Shared signup IP</th>
                <th className="px-4 py-3">Reward invalid (7d)</th>
                <th className="px-4 py-3">Reward lock</th>
              </tr>
            </thead>
            <tbody>
              {suspicious.map((item) => (
                <tr key={item.user_id} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <p className="font-bold">{item.email}</p>
                    <p className="text-xs text-muted-foreground">{item.user_id}</p>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-1">
                      {item.reasons.map((reason) => (
                        <AdminBadge key={reason} tone="warning">
                          {reason.replaceAll("_", " ")}
                        </AdminBadge>
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-3">{item.rate_limit_hits_24h}</td>
                  <td className="px-4 py-3">{item.shared_signup_ip_accounts_7d}</td>
                  <td className="px-4 py-3">
                    {item.reward_invalid_7d} / {item.reward_valid_7d + item.reward_invalid_7d}
                    {" · "}
                    {(item.reward_invalid_ratio_7d * 100).toFixed(0)}%
                  </td>
                  <td className="px-4 py-3 text-xs">{dateTime(item.reward_locked_until)}</td>
                </tr>
              ))}
              {!suspicious.length && (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    No accounts currently exceed the D8 risk thresholds.
                  </td>
                </tr>
              )}
            </tbody>
          </AdminDataTable>
        </TabsContent>

        {/* Loads on open (Radix unmounts inactive tabs). */}
        <TabsContent value="downloader">
          <VideoDownloaderAdminTab />
        </TabsContent>
      </Tabs>

      <CreateComplaintDialog
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreated={(complaint) => setComplaints((current) => [complaint, ...current])}
      />
      <ComplaintDetailDialog
        complaint={selectedComplaint}
        onClose={() => setSelectedComplaint(null)}
        onUpdated={(updated) => {
          setComplaints((current) =>
            current.map((item) => (item.id === updated.id ? updated : item)),
          );
          setSelectedComplaint(updated);
        }}
        onBlockForAccount={setChannelBlockAction}
      />
      <SafetyActionDialog action={action} onClose={() => setAction(null)} onDone={load} />
      <ChannelAccountBlockDialog
        action={channelBlockAction}
        onClose={() => setChannelBlockAction(null)}
        onDone={load}
      />
    </AppShell>
  );
}
