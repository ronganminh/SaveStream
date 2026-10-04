import { useEffect, useMemo, useState } from "react";
import {
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
  adminSafetyApi,
  type AdminComplaint,
  type AdminComplaintFilters,
  type AdminCreatorBlock,
  type AdminSuspiciousAccount,
} from "@/repositories/admin-api";

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString("en-US") : "—";
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
          <Input placeholder="Complainant name" value={name} onChange={(event) => setName(event.target.value)} />
          <Input placeholder="Complainant email" value={email} onChange={(event) => setEmail(event.target.value)} />
          <Input placeholder="Recording ID (optional)" value={recordingId} onChange={(event) => setRecordingId(event.target.value)} />
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
          <Input placeholder="Channel / source value" value={sourceValue} onChange={(event) => setSourceValue(event.target.value)} />
          <Input className="sm:col-span-2" placeholder="Summary" value={summary} onChange={(event) => setSummary(event.target.value)} />
          <textarea
            className="min-h-28 rounded-md border bg-background px-3 py-2 text-sm sm:col-span-2"
            placeholder="Complaint details"
            value={body}
            onChange={(event) => setBody(event.target.value)}
          />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>Cancel</Button>
          <Button onClick={() => void submit()} disabled={!valid || busy}>
            {busy ? "Creating…" : "Create case"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function ComplaintDetailDialog({
  complaint,
  onClose,
  onUpdated,
}: {
  complaint: AdminComplaint | null;
  onClose: () => void;
  onUpdated: (complaint: AdminComplaint) => void;
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
            {full ? `${full.kind} · ${full.complainant_email} · ${dateTime(full.created_at)}` : "Loading…"}
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
                onChange={(event) =>
                  setStatus(event.target.value as AdminComplaint["status"])
                }
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

            <div>
              <h3 className="mb-2 font-medium">Timeline</h3>
              <div className="space-y-2">
                {full.timeline.map((event) => (
                  <div key={event.id} className="rounded-md border p-3 text-sm">
                    <div className="flex justify-between gap-3">
                      <span className="font-medium">{event.action}</span>
                      <span className="text-xs text-muted-foreground">{dateTime(event.created_at)}</span>
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
            This dangerous action requires password re-entry, an authenticator code, a reason, and is permanently audited.
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
          <Input placeholder="Reason" value={reason} onChange={(event) => setReason(event.target.value)} />
          <Input type="password" placeholder="Password" value={password} onChange={(event) => setPassword(event.target.value)} />
          <Input inputMode="numeric" maxLength={6} placeholder="Authenticator code" value={totp} onChange={(event) => setTotp(event.target.value)} />
        </div>
        <DialogFooter>
          <Button variant="outline" disabled={busy} onClick={onClose}>Cancel</Button>
          <Button disabled={!valid || busy} onClick={() => void submit()}>
            {busy ? "Confirming…" : "Confirm"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export function AdminSafetyD8Page() {
  const { identity } = useAuth();
  const canUseSafety = ["owner", "admin", "support"].includes(identity.role);
  const [filters, setFilters] = useState<AdminComplaintFilters>({});
  const [complaints, setComplaints] = useState<AdminComplaint[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [blocks, setBlocks] = useState<AdminCreatorBlock[]>([]);
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
      const [complaintResult, blockResult, suspiciousResult] = await Promise.all([
        adminSafetyApi.listComplaints(filters),
        adminSafetyApi.listCreatorBlocks(true),
        adminSafetyApi.suspiciousAccounts(),
      ]);
      setComplaints(complaintResult.items);
      setNextCursor(complaintResult.next_cursor);
      setHasMore(complaintResult.has_more);
      setBlocks(blockResult.items);
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
      open: complaints.filter((item) => item.status === "new" || item.status === "reviewing").length,
      blocks: blocks.length,
      suspicious: suspicious.length,
    }),
    [blocks.length, complaints, suspicious.length],
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
        <PageHeader
          title="Safety"
          subtitle="Complaint and creator-safety operations."
        />
        <div className="rounded-lg border bg-background p-6">
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
              <RefreshCw className="mr-2 size-4" />
              Refresh
            </Button>
            <Button onClick={() => setCreateOpen(true)}>
              <Plus className="mr-2 size-4" />
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
        <TabsList>
          <TabsTrigger value="complaints">Complaints</TabsTrigger>
          <TabsTrigger value="blocks">Creator blocks</TabsTrigger>
          <TabsTrigger value="suspicious">Suspicious accounts</TabsTrigger>
        </TabsList>

        <TabsContent value="complaints" className="space-y-4">
          <div className="grid gap-3 rounded-lg border bg-background p-4 md:grid-cols-4">
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
                <Download className="mr-1 size-4" />
                CSV
              </Button>
            </div>
          </div>

          <AdminDataTable>
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
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
                    <p className="font-medium">{item.summary}</p>
                    <p className="text-xs text-muted-foreground">{item.kind} · {item.id}</p>
                  </td>
                  <td className="px-4 py-3 text-sm">{item.channel_source_value ?? item.recording_id ?? "—"}</td>
                  <td className="px-4 py-3 text-sm">{item.complainant_email}</td>
                  <td className="px-4 py-3 text-sm">{item.status}</td>
                  <td className="px-4 py-3 text-xs">{dateTime(item.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button size="sm" variant="outline" onClick={() => setSelectedComplaint(item)}>
                        <ExternalLink className="mr-1 size-3" />
                        Review
                      </Button>
                      {item.channel_source_value && (
                        <Button size="sm" variant="outline" onClick={() => setAction({ mode: "block", complaint: item })}>
                          <ShieldAlert className="mr-1 size-3" />
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
              <ShieldAlert className="mr-2 size-4" />
              Block creator
            </Button>
          </div>
          <AdminDataTable>
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
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
                    <p className="font-medium">{block.source_value}</p>
                    <p className="text-xs text-muted-foreground">{block.source_type}</p>
                  </td>
                  <td className="max-w-sm truncate px-4 py-3 text-sm">{block.reason}</td>
                  <td className="px-4 py-3 text-xs">{block.complaint_id ?? "—"}</td>
                  <td className="px-4 py-3 text-xs">{dateTime(block.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button size="sm" variant="outline" onClick={() => setAction({ mode: "delete", block })}>
                        <Trash2 className="mr-1 size-3" />
                        Delete recordings
                      </Button>
                      <Button size="sm" variant="outline" onClick={() => setAction({ mode: "unblock", block })}>
                        <Unlock className="mr-1 size-3" />
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
            Deleting locked recordings never issues an automatic credit refund. Use Payments for any manual refund or credit adjustment.
          </p>
        </TabsContent>

        <TabsContent value="suspicious">
          <AdminDataTable>
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
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
                    <p className="font-medium">{item.email}</p>
                    <p className="text-xs text-muted-foreground">{item.user_id}</p>
                  </td>
                  <td className="px-4 py-3 text-xs">{item.reasons.join(", ")}</td>
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
      />
      <SafetyActionDialog
        action={action}
        onClose={() => setAction(null)}
        onDone={load}
      />
    </AppShell>
  );
}
