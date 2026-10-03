import { useEffect, useMemo, useState } from "react";
import { Download, RefreshCw, Send, ShieldAlert, Trash2 } from "lucide-react";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  adminFoundationApi,
  adminOperationsApi,
  type AdminBroadcast,
  type AdminBroadcastFilters,
  type AdminEmailFilters,
  type AdminEmailLog,
  type AdminEmailTemplate,
  type AdminStorageRun,
  type AdminStorageSummary,
} from "@/repositories/admin-api";

function bytes(value: number) {
  if (value < 1024) return `${value} B`;
  if (value < 1024 ** 2) return `${(value / 1024).toFixed(1)} KB`;
  if (value < 1024 ** 3) return `${(value / 1024 ** 2).toFixed(1)} MB`;
  return `${(value / 1024 ** 3).toFixed(2)} GB`;
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString("en-US") : "—";
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

type DangerousAction = {
  title: string;
  reason: string;
  execute: (stepUpToken: string, reason: string) => Promise<void>;
};

function StepUpDialog({
  action,
  onClose,
}: {
  action: DangerousAction | null;
  onClose: () => void;
}) {
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!action) return;
    setPassword("");
    setTotp("");
    setReason(action.reason);
  }, [action]);

  const confirm = async () => {
    if (!action) return;
    setBusy(true);
    try {
      const grant = await adminFoundationApi.stepUp(password, totp);
      await action.execute(grant.token, reason.trim());
      onClose();
    } catch (error) {
      toast.error("Action failed", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={action !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{action?.title ?? "Confirm admin action"}</DialogTitle>
          <DialogDescription>
            Re-enter your password, current authenticator code, and the reason for this action.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
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
          <Input
            placeholder="Reason"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button
            disabled={busy || !password || totp.length !== 6 || reason.trim().length < 3}
            onClick={() => void confirm()}
          >
            {busy ? "Confirming…" : "Confirm"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export function AdminOperationsPage() {
  const { user } = useAuth();
  const isOwner = user?.role === "owner" || user?.role === "admin";
  const canViewEmail = isOwner || user?.role === "support";

  const [storage, setStorage] = useState<AdminStorageSummary | null>(null);
  const [storageError, setStorageError] = useState<string | null>(null);
  const [scanReason, setScanReason] = useState("");
  const [scanLimit, setScanLimit] = useState("1000");
  const [storageRun, setStorageRun] = useState<AdminStorageRun | null>(null);

  const [emailFilters, setEmailFilters] = useState<AdminEmailFilters>({ sortOrder: "desc" });
  const [emailDraft, setEmailDraft] = useState<AdminEmailFilters>({ sortOrder: "desc" });
  const [emailLogs, setEmailLogs] = useState<AdminEmailLog[]>([]);
  const [emailCursor, setEmailCursor] = useState<string | null>(null);
  const [emailNext, setEmailNext] = useState<string | null>(null);
  const [emailHistory, setEmailHistory] = useState<Array<string | null>>([]);
  const [templates, setTemplates] = useState<AdminEmailTemplate[]>([]);
  const [selectedTemplate, setSelectedTemplate] = useState<AdminEmailTemplate | null>(null);
  const [templateSubject, setTemplateSubject] = useState("");
  const [templateBody, setTemplateBody] = useState("");
  const [templateReason, setTemplateReason] = useState("");

  const [broadcastFilters, setBroadcastFilters] = useState<AdminBroadcastFilters>({ sortOrder: "desc" });
  const [broadcastDraft, setBroadcastDraft] = useState<AdminBroadcastFilters>({ sortOrder: "desc" });
  const [broadcasts, setBroadcasts] = useState<AdminBroadcast[]>([]);
  const [broadcastCursor, setBroadcastCursor] = useState<string | null>(null);
  const [broadcastNext, setBroadcastNext] = useState<string | null>(null);
  const [broadcastHistory, setBroadcastHistory] = useState<Array<string | null>>([]);
  const [broadcastKind, setBroadcastKind] = useState<"system" | "marketing">("system");
  const [broadcastChannels, setBroadcastChannels] = useState<AdminBroadcast["channels"]>(["in_app"]);
  const [broadcastTitle, setBroadcastTitle] = useState("");
  const [broadcastBody, setBroadcastBody] = useState("");
  const [broadcastReason, setBroadcastReason] = useState("");
  const [audience, setAudience] = useState<number | null>(null);

  const [danger, setDanger] = useState<DangerousAction | null>(null);

  const loadStorage = async () => {
    try {
      setStorage(await adminOperationsApi.storageSummary());
      setStorageError(null);
    } catch (error) {
      setStorageError(authErrorMessage(error));
    }
  };

  const loadEmail = async () => {
    if (!canViewEmail) return;
    try {
      const result = await adminOperationsApi.listEmailLogs({
        ...emailFilters,
        cursor: emailCursor,
      });
      setEmailLogs(result.items);
      setEmailNext(result.pagination.next_cursor);
    } catch (error) {
      toast.error("Could not load email logs", { description: authErrorMessage(error) });
    }
  };

  const loadOwnerData = async () => {
    if (!isOwner) return;
    try {
      const [templateRows, broadcastRows] = await Promise.all([
        adminOperationsApi.listEmailTemplates(),
        adminOperationsApi.listBroadcasts({ ...broadcastFilters, cursor: broadcastCursor }),
      ]);
      setTemplates(templateRows);
      setBroadcasts(broadcastRows.items);
      setBroadcastNext(broadcastRows.pagination.next_cursor);
      if (!selectedTemplate && templateRows[0]) {
        setSelectedTemplate(templateRows[0]);
        setTemplateSubject(templateRows[0].subject);
        setTemplateBody(templateRows[0].body);
      }
    } catch (error) {
      toast.error("Could not load owner operations", { description: authErrorMessage(error) });
    }
  };

  useEffect(() => {
    void loadStorage();
  }, []);

  useEffect(() => {
    void loadEmail();
  }, [canViewEmail, emailFilters, emailCursor]);

  useEffect(() => {
    void loadOwnerData();
  }, [isOwner, broadcastFilters, broadcastCursor]);

  const latestCleanup = storage?.latest_cleanup;
  const broadcastChannelLabel = useMemo(() => broadcastChannels.join(", "), [broadcastChannels]);

  const refreshRun = async () => {
    if (!storageRun) return;
    try {
      setStorageRun(await adminOperationsApi.getStorageRun(storageRun.id));
      await loadStorage();
    } catch (error) {
      toast.error("Could not refresh storage run", { description: authErrorMessage(error) });
    }
  };

  const startScan = async () => {
    try {
      const run = await adminOperationsApi.createOrphanScan(
        Math.max(1, Math.min(Number(scanLimit) || 1000, 5000)),
        scanReason.trim(),
      );
      setStorageRun(run);
      toast.success("Orphan scan queued");
    } catch (error) {
      toast.error("Could not queue orphan scan", { description: authErrorMessage(error) });
    }
  };

  const editTemplate = (row: AdminEmailTemplate) => {
    setSelectedTemplate(row);
    setTemplateSubject(row.subject);
    setTemplateBody(row.body);
    setTemplateReason("");
  };

  const toggleChannel = (channel: AdminBroadcast["channels"][number]) => {
    setBroadcastChannels((current) =>
      current.includes(channel)
        ? current.filter((item) => item !== channel)
        : [...current, channel],
    );
  };

  return (
    <AdminMfaGate>
      <AppShell>
        <PageHeader
          title="Operations"
          subtitle="Storage, email delivery, templates, and broadcast operations."
          action={
            <Button variant="outline" onClick={() => void loadStorage()}>
              <RefreshCw className="size-4" />
              Refresh
            </Button>
          }
        />

        <Tabs defaultValue="storage">
          <TabsList className="mb-6 flex h-auto flex-wrap">
            <TabsTrigger value="storage">Storage</TabsTrigger>
            {canViewEmail && <TabsTrigger value="email">Email</TabsTrigger>}
            {isOwner && <TabsTrigger value="broadcasts">Broadcasts</TabsTrigger>}
          </TabsList>

          <TabsContent value="storage" className="space-y-6">
            {storageError && <p className="text-sm text-destructive">{storageError}</p>}
            <div className="grid gap-3 md:grid-cols-3">
              <AdminMetricCard
                label="Stored artifact data"
                value={storage ? bytes(storage.total_bytes) : "Loading…"}
                detail="Active artifact rows in the database"
              />
              <AdminMetricCard
                label="Latest cleanup"
                value={latestCleanup ? String(latestCleanup.deleted_count) : "—"}
                detail={latestCleanup ? `${latestCleanup.scanned_count} files checked · ${dateTime(latestCleanup.created_at)}` : "No cleanup run recorded yet"}
              />
              <AdminMetricCard
                label="Users with stored data"
                value={String(storage?.by_user.length ?? 0)}
                detail="Top 100 by stored bytes"
              />
            </div>

            <section className="space-y-3">
              <h2 className="text-lg font-semibold">Storage by user</h2>
              <AdminDataTable>
                <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                  <tr><th className="px-4 py-3">User</th><th className="px-4 py-3">Stored</th></tr>
                </thead>
                <tbody>
                  {(storage?.by_user ?? []).map((row) => (
                    <tr key={row.user_id} className="border-b last:border-0">
                      <td className="px-4 py-3">{row.email}</td>
                      <td className="px-4 py-3">{bytes(row.bytes)}</td>
                    </tr>
                  ))}
                </tbody>
              </AdminDataTable>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-semibold">30-day storage trend</h2>
              <AdminDataTable>
                <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                  <tr><th className="px-4 py-3">Day</th><th className="px-4 py-3">Uploaded bytes</th></tr>
                </thead>
                <tbody>
                  {(storage?.daily_trend ?? []).map((row) => (
                    <tr key={row.day} className="border-b last:border-0">
                      <td className="px-4 py-3">{row.day}</td>
                      <td className="px-4 py-3">{bytes(row.bytes)}</td>
                    </tr>
                  ))}
                </tbody>
              </AdminDataTable>
            </section>

            {isOwner && (
              <section className="space-y-4 rounded-lg border p-4">
                <div>
                  <h2 className="font-semibold">Orphan file scan</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Bounded object-storage scan. Files are never deleted by the scan itself.
                  </p>
                </div>
                <div className="grid gap-3 md:grid-cols-[160px_1fr_auto]">
                  <Input
                    type="number"
                    min={1}
                    max={5000}
                    value={scanLimit}
                    onChange={(event) => setScanLimit(event.target.value)}
                    aria-label="Scan limit"
                  />
                  <Input
                    placeholder="Reason for scan"
                    value={scanReason}
                    onChange={(event) => setScanReason(event.target.value)}
                  />
                  <Button disabled={scanReason.trim().length < 3} onClick={() => void startScan()}>
                    Start scan
                  </Button>
                </div>
                {storageRun && (
                  <div className="rounded-md bg-muted/40 p-3 text-sm">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span>
                        Run {storageRun.id.slice(0, 8)} · {storageRun.status} · {storageRun.orphan_count} orphan files
                      </span>
                      <div className="flex gap-2">
                        <Button size="sm" variant="outline" onClick={() => void refreshRun()}>
                          Refresh
                        </Button>
                        {storageRun.kind === "orphan_scan" &&
                          storageRun.status === "completed" &&
                          storageRun.orphan_count > 0 && (
                            <Button
                              size="sm"
                              variant="destructive"
                              onClick={() =>
                                setDanger({
                                  title: "Delete orphan files",
                                  reason: "Delete files confirmed orphaned by bounded scan",
                                  execute: async (token, reason) => {
                                    setStorageRun(
                                      await adminOperationsApi.deleteOrphans(
                                        storageRun.id,
                                        reason,
                                        token,
                                      ),
                                    );
                                    toast.success("Orphan deletion queued");
                                  },
                                })
                              }
                            >
                              <Trash2 className="size-4" />
                              Delete orphans
                            </Button>
                          )}
                      </div>
                    </div>
                    {storageRun.truncated && (
                      <p className="mt-2 text-warning">Scan hit its limit; run another scan before assuming storage is fully reconciled.</p>
                    )}
                    {storageRun.error && <p className="mt-2 text-destructive">{storageRun.error}</p>}
                  </div>
                )}
              </section>
            )}
          </TabsContent>

          {canViewEmail && (
            <TabsContent value="email" className="space-y-6">
              <section className="space-y-3">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <h2 className="text-lg font-semibold">Email delivery logs</h2>
                  <Button
                    variant="outline"
                    onClick={() =>
                      void adminOperationsApi
                        .exportEmailLogs(emailFilters)
                        .then((csv) => downloadText("savestream-admin-email-logs.csv", csv))
                        .catch((error) => toast.error(authErrorMessage(error)))
                    }
                  >
                    <Download className="size-4" />
                    Export CSV
                  </Button>
                </div>
                <div className="grid gap-3 md:grid-cols-4">
                  <Input
                    placeholder="Search recipient"
                    value={emailDraft.recipient ?? ""}
                    onChange={(event) => setEmailDraft((current) => ({ ...current, recipient: event.target.value }))}
                  />
                  <Input
                    placeholder="Type e.g. password_reset"
                    value={emailDraft.kind ?? ""}
                    onChange={(event) => setEmailDraft((current) => ({ ...current, kind: event.target.value }))}
                  />
                  <select
                    className="h-10 rounded-md border bg-background px-3 text-sm"
                    value={emailDraft.status ?? ""}
                    onChange={(event) => setEmailDraft((current) => ({ ...current, status: event.target.value }))}
                  >
                    <option value="">All statuses</option>
                    <option value="sent">Sent</option>
                    <option value="failed">Failed</option>
                    <option value="sending">Sending</option>
                  </select>
                  <select
                    className="h-10 rounded-md border bg-background px-3 text-sm"
                    value={emailDraft.sortOrder ?? "desc"}
                    onChange={(event) => setEmailDraft((current) => ({ ...current, sortOrder: event.target.value as "asc" | "desc" }))}
                  >
                    <option value="desc">Newest first</option>
                    <option value="asc">Oldest first</option>
                  </select>
                </div>
                <Button
                  variant="secondary"
                  onClick={() => {
                    setEmailHistory([]);
                    setEmailCursor(null);
                    setEmailFilters(emailDraft);
                  }}
                >
                  Apply filters
                </Button>
                <AdminDataTable>
                  <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                    <tr>
                      <th className="px-4 py-3">Recipient</th>
                      <th className="px-4 py-3">Type</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3">Sent</th>
                      <th className="px-4 py-3 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {emailLogs.map((row) => (
                      <tr key={row.id} className="border-b last:border-0">
                        <td className="px-4 py-3">{row.recipient_email}</td>
                        <td className="px-4 py-3">{row.kind}</td>
                        <td className="px-4 py-3">{row.status}</td>
                        <td className="px-4 py-3">{dateTime(row.sent_at ?? row.created_at)}</td>
                        <td className="px-4 py-3 text-right">
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => {
                              const reason = window.prompt("Reason for resending this email:");
                              if (!reason || reason.trim().length < 3) return;
                              void adminOperationsApi
                                .resendEmail(row.id, reason.trim())
                                .then(() => {
                                  toast.success("Email resend queued or sent");
                                  void loadEmail();
                                })
                                .catch((error) => toast.error(authErrorMessage(error)));
                            }}
                          >
                            Resend
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </AdminDataTable>
                <div className="flex justify-end gap-2">
                  <Button
                    variant="outline"
                    disabled={!emailHistory.length}
                    onClick={() => {
                      const previous = emailHistory[emailHistory.length - 1] ?? null;
                      setEmailHistory((current) => current.slice(0, -1));
                      setEmailCursor(previous);
                    }}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    disabled={!emailNext}
                    onClick={() => {
                      setEmailHistory((current) => [...current, emailCursor]);
                      setEmailCursor(emailNext);
                    }}
                  >
                    Next
                  </Button>
                </div>
              </section>

              {isOwner && (
                <section className="space-y-4 rounded-lg border p-4">
                  <div>
                    <h2 className="font-semibold">Email templates</h2>
                    <p className="mt-1 text-sm text-muted-foreground">
                      Subject and main body are editable. The HTML shell remains version-controlled.
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {templates.map((row) => (
                      <Button
                        key={row.key}
                        size="sm"
                        variant={selectedTemplate?.key === row.key ? "default" : "outline"}
                        onClick={() => editTemplate(row)}
                      >
                        {row.key}
                      </Button>
                    ))}
                  </div>
                  {selectedTemplate && (
                    <div className="space-y-3">
                      <Input value={templateSubject} onChange={(event) => setTemplateSubject(event.target.value)} />
                      <textarea
                        className="min-h-32 w-full rounded-md border bg-background p-3 text-sm"
                        value={templateBody}
                        onChange={(event) => setTemplateBody(event.target.value)}
                      />
                      <Input
                        placeholder="Reason for template change or test"
                        value={templateReason}
                        onChange={(event) => setTemplateReason(event.target.value)}
                      />
                      <div className="flex flex-wrap gap-2">
                        <Button
                          variant="outline"
                          onClick={() =>
                            void adminOperationsApi
                              .previewEmailTemplate(selectedTemplate.key)
                              .then((preview) => window.alert(`${preview.subject}\n\n${preview.text}`))
                              .catch((error) => toast.error(authErrorMessage(error)))
                          }
                        >
                          Preview
                        </Button>
                        <Button
                          variant="outline"
                          disabled={templateReason.trim().length < 3}
                          onClick={() =>
                            void adminOperationsApi
                              .testEmailTemplate(selectedTemplate.key, templateReason.trim())
                              .then(() => toast.success("Test email sent to your admin address"))
                              .catch((error) => toast.error(authErrorMessage(error)))
                          }
                        >
                          Send test
                        </Button>
                        <Button
                          disabled={templateReason.trim().length < 3}
                          onClick={() =>
                            setDanger({
                              title: "Update email template",
                              reason: templateReason,
                              execute: async (token, reason) => {
                                const updated = await adminOperationsApi.updateEmailTemplate(
                                  selectedTemplate.key,
                                  templateSubject,
                                  templateBody,
                                  reason,
                                  token,
                                );
                                setTemplates((current) =>
                                  current.map((item) => item.key === updated.key ? updated : item),
                                );
                                setSelectedTemplate(updated);
                                toast.success("Email template updated");
                              },
                            })
                          }
                        >
                          Save override
                        </Button>
                        {selectedTemplate.overridden && (
                          <Button
                            variant="destructive"
                            disabled={templateReason.trim().length < 3}
                            onClick={() =>
                              setDanger({
                                title: "Reset email template",
                                reason: templateReason,
                                execute: async (token, reason) => {
                                  await adminOperationsApi.resetEmailTemplate(
                                    selectedTemplate.key,
                                    reason,
                                    token,
                                  );
                                  const fresh = await adminOperationsApi.listEmailTemplates();
                                  setTemplates(fresh);
                                  const current = fresh.find((item) => item.key === selectedTemplate.key) ?? fresh[0];
                                  if (current) editTemplate(current);
                                  toast.success("Email template reset");
                                },
                              })
                            }
                          >
                            Reset default
                          </Button>
                        )}
                      </div>
                    </div>
                  )}
                </section>
              )}
            </TabsContent>
          )}

          {isOwner && (
            <TabsContent value="broadcasts" className="space-y-6">
              <section className="space-y-4 rounded-lg border p-4">
                <div className="flex items-center gap-2">
                  <ShieldAlert className="size-5" />
                  <div>
                    <h2 className="font-semibold">Compose broadcast</h2>
                    <p className="text-sm text-muted-foreground">
                      System reaches every active account. Marketing reaches only users who opted in.
                    </p>
                  </div>
                </div>
                <div className="grid gap-3 md:grid-cols-2">
                  <select
                    className="h-10 rounded-md border bg-background px-3 text-sm"
                    value={broadcastKind}
                    onChange={(event) => {
                      setBroadcastKind(event.target.value as "system" | "marketing");
                      setAudience(null);
                    }}
                  >
                    <option value="system">System</option>
                    <option value="marketing">Marketing</option>
                  </select>
                  <div className="flex flex-wrap gap-3 rounded-md border px-3 py-2 text-sm">
                    {(["in_app", "push", "email"] as const).map((channel) => (
                      <label key={channel} className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={broadcastChannels.includes(channel)}
                          onChange={() => toggleChannel(channel)}
                        />
                        {channel}
                      </label>
                    ))}
                  </div>
                </div>
                <Input placeholder="Title" value={broadcastTitle} onChange={(event) => setBroadcastTitle(event.target.value)} />
                <textarea
                  className="min-h-28 w-full rounded-md border bg-background p-3 text-sm"
                  placeholder="Message"
                  value={broadcastBody}
                  onChange={(event) => setBroadcastBody(event.target.value)}
                />
                <Input
                  placeholder="Reason"
                  value={broadcastReason}
                  onChange={(event) => setBroadcastReason(event.target.value)}
                />
                <div className="flex flex-wrap items-center gap-2">
                  <Button
                    variant="outline"
                    disabled={!broadcastChannels.length}
                    onClick={() =>
                      void adminOperationsApi
                        .previewBroadcast(broadcastKind, broadcastChannels)
                        .then((result) => setAudience(result.audience_count))
                        .catch((error) => toast.error(authErrorMessage(error)))
                    }
                  >
                    Preview audience
                  </Button>
                  {audience !== null && (
                    <span className="text-sm text-muted-foreground">
                      {audience} recipients · {broadcastChannelLabel}
                    </span>
                  )}
                  <Button
                    disabled={
                      !broadcastChannels.length ||
                      !broadcastTitle.trim() ||
                      !broadcastBody.trim() ||
                      broadcastReason.trim().length < 3
                    }
                    onClick={() =>
                      setDanger({
                        title: "Send broadcast",
                        reason: broadcastReason,
                        execute: async (token, reason) => {
                          await adminOperationsApi.createBroadcast(
                            {
                              kind: broadcastKind,
                              channels: broadcastChannels,
                              title: broadcastTitle,
                              body: broadcastBody,
                              reason,
                            },
                            token,
                          );
                          toast.success("Broadcast queued");
                          setBroadcastTitle("");
                          setBroadcastBody("");
                          setBroadcastReason("");
                          setAudience(null);
                          await loadOwnerData();
                        },
                      })
                    }
                  >
                    <Send className="size-4" />
                    Queue broadcast
                  </Button>
                </div>
              </section>

              <section className="space-y-3">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <h2 className="text-lg font-semibold">Broadcast history</h2>
                  <Button
                    variant="outline"
                    onClick={() =>
                      void adminOperationsApi
                        .exportBroadcasts(broadcastFilters)
                        .then((csv) => downloadText("savestream-admin-broadcasts.csv", csv))
                        .catch((error) => toast.error(authErrorMessage(error)))
                    }
                  >
                    <Download className="size-4" />
                    Export CSV
                  </Button>
                </div>
                <div className="grid gap-3 md:grid-cols-4">
                  <Input
                    placeholder="Search title or message"
                    value={broadcastDraft.query ?? ""}
                    onChange={(event) => setBroadcastDraft((current) => ({ ...current, query: event.target.value }))}
                  />
                  <select
                    className="h-10 rounded-md border bg-background px-3 text-sm"
                    value={broadcastDraft.kind ?? ""}
                    onChange={(event) => setBroadcastDraft((current) => ({ ...current, kind: event.target.value as "" | "system" | "marketing" }))}
                  >
                    <option value="">All types</option>
                    <option value="system">System</option>
                    <option value="marketing">Marketing</option>
                  </select>
                  <Input
                    placeholder="Status"
                    value={broadcastDraft.status ?? ""}
                    onChange={(event) => setBroadcastDraft((current) => ({ ...current, status: event.target.value }))}
                  />
                  <select
                    className="h-10 rounded-md border bg-background px-3 text-sm"
                    value={broadcastDraft.sortOrder ?? "desc"}
                    onChange={(event) => setBroadcastDraft((current) => ({ ...current, sortOrder: event.target.value as "asc" | "desc" }))}
                  >
                    <option value="desc">Newest first</option>
                    <option value="asc">Oldest first</option>
                  </select>
                </div>
                <Button
                  variant="secondary"
                  onClick={() => {
                    setBroadcastHistory([]);
                    setBroadcastCursor(null);
                    setBroadcastFilters(broadcastDraft);
                  }}
                >
                  Apply filters
                </Button>
                <AdminDataTable>
                  <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                    <tr>
                      <th className="px-4 py-3">Broadcast</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3">Audience</th>
                      <th className="px-4 py-3">Delivered</th>
                      <th className="px-4 py-3">Failed</th>
                    </tr>
                  </thead>
                  <tbody>
                    {broadcasts.map((row) => (
                      <tr key={row.id} className="border-b last:border-0">
                        <td className="px-4 py-3">
                          <div className="font-medium">{row.title}</div>
                          <div className="text-xs text-muted-foreground">{row.kind} · {row.channels.join(", ")}</div>
                        </td>
                        <td className="px-4 py-3">{row.status}</td>
                        <td className="px-4 py-3">{row.audience_count}</td>
                        <td className="px-4 py-3">
                          {row.delivered_in_app + row.delivered_push + row.delivered_email}
                        </td>
                        <td className="px-4 py-3">{row.failed_count}</td>
                      </tr>
                    ))}
                  </tbody>
                </AdminDataTable>
                <div className="flex justify-end gap-2">
                  <Button
                    variant="outline"
                    disabled={!broadcastHistory.length}
                    onClick={() => {
                      const previous = broadcastHistory[broadcastHistory.length - 1] ?? null;
                      setBroadcastHistory((current) => current.slice(0, -1));
                      setBroadcastCursor(previous);
                    }}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    disabled={!broadcastNext}
                    onClick={() => {
                      setBroadcastHistory((current) => [...current, broadcastCursor]);
                      setBroadcastCursor(broadcastNext);
                    }}
                  >
                    Next
                  </Button>
                </div>
              </section>
            </TabsContent>
          )}
        </Tabs>

        <StepUpDialog action={danger} onClose={() => setDanger(null)} />
      </AppShell>
    </AdminMfaGate>
  );
}
