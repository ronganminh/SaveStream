import { useEffect, useMemo, useState } from "react";
import { Download, Eye, Search } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, PageHeader } from "@/components/app-components";
import {
  AdminDataTable,
  AdminGlobalSearch,
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
  type AdminPrivacyRequest,
  type AdminUser,
  type AdminUserDetail,
  type AdminUserFilters,
  type AdminViewAsUser,
} from "@/repositories/admin-api";

function accountStatus(user: AdminUser) {
  if (user.deletion_requested_at) return "Pending deletion";
  return user.is_active ? "Active" : "Locked";
}

function dateTime(value: string | null | undefined) {
  if (!value) return "—";
  return new Date(value).toLocaleString("en-US");
}

function downloadText(filename: string, content: string, type: string) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

export function AdminUsersPage() {
  const [filters, setFilters] = useState<AdminUserFilters>({
    sortBy: "created_at",
    sortOrder: "desc",
  });
  const [draft, setDraft] = useState(filters);
  const [items, setItems] = useState<AdminUser[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [cursor, setCursor] = useState<string | null>(null);
  const [history, setHistory] = useState<Array<string | null>>([]);
  const [privacy, setPrivacy] = useState<AdminPrivacyRequest[]>([]);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = async (activeFilters: AdminUserFilters, activeCursor: string | null) => {
    setBusy(true);
    setError(null);
    try {
      const [users, privacyResult] = await Promise.all([
        adminFoundationApi.listUsers({ ...activeFilters, cursor: activeCursor }),
        adminFoundationApi.listPrivacyRequests(),
      ]);
      setItems(users.items);
      setNextCursor(users.pagination.next_cursor);
      setPrivacy(privacyResult.items);
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load(filters, cursor);
  }, [filters, cursor]);

  const applyFilters = () => {
    setHistory([]);
    setCursor(null);
    setFilters({
      ...draft,
      createdFrom: draft.createdFrom ? `${draft.createdFrom}T00:00:00Z` : undefined,
      createdTo: draft.createdTo ? `${draft.createdTo}T23:59:59Z` : undefined,
    });
  };

  const exportCsv = async () => {
    try {
      const csv = await adminFoundationApi.exportUsers(filters);
      downloadText("savestream-admin-users.csv", csv, "text/csv;charset=utf-8");
    } catch (requestError) {
      toast.error(authErrorMessage(requestError));
    }
  };

  return (
    <AdminMfaGate>
      <AppShell>
        <PageHeader
          title="Users"
          subtitle="Search, filter, support, and audit SaveStream accounts."
          action={
            <Button variant="outline" onClick={() => void exportCsv()}>
              <Download className="size-4" />
              Export CSV
            </Button>
          }
        />

        <div className="mb-6">
          <AdminGlobalSearch />
        </div>

        <section className="rounded-lg border bg-background p-4">
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            <Input
              placeholder="Search email"
              value={draft.query ?? ""}
              onChange={(event) => setDraft((value) => ({ ...value, query: event.target.value }))}
            />
            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={draft.plan ?? ""}
              onChange={(event) =>
                setDraft((value) => ({ ...value, plan: event.target.value as AdminUserFilters["plan"] }))
              }
            >
              <option value="">All plans</option>
              <option value="free">Free</option>
              <option value="pro">Pro</option>
            </select>
            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={draft.accountStatus ?? ""}
              onChange={(event) =>
                setDraft((value) => ({
                  ...value,
                  accountStatus: event.target.value as AdminUserFilters["accountStatus"],
                }))
              }
            >
              <option value="">All account states</option>
              <option value="active">Active</option>
              <option value="locked">Locked</option>
              <option value="pending_deletion">Pending deletion</option>
              <option value="deleted">Deleted</option>
            </select>
            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={draft.emailVerified ?? ""}
              onChange={(event) =>
                setDraft((value) => ({
                  ...value,
                  emailVerified: event.target.value as AdminUserFilters["emailVerified"],
                }))
              }
            >
              <option value="">Any email state</option>
              <option value="true">Verified</option>
              <option value="false">Unverified</option>
            </select>
            <Input
              type="date"
              aria-label="Registered from"
              value={draft.createdFrom?.slice(0, 10) ?? ""}
              onChange={(event) =>
                setDraft((value) => ({ ...value, createdFrom: event.target.value || undefined }))
              }
            />
            <Input
              type="date"
              aria-label="Registered to"
              value={draft.createdTo?.slice(0, 10) ?? ""}
              onChange={(event) =>
                setDraft((value) => ({ ...value, createdTo: event.target.value || undefined }))
              }
            />
            <Input
              placeholder="Latest purchase provider"
              value={draft.purchaseProvider ?? ""}
              onChange={(event) =>
                setDraft((value) => ({ ...value, purchaseProvider: event.target.value }))
              }
            />
            <div className="flex gap-2">
              <select
                className="h-10 flex-1 rounded-md border bg-background px-3 text-sm"
                value={draft.sortBy ?? "created_at"}
                onChange={(event) =>
                  setDraft((value) => ({
                    ...value,
                    sortBy: event.target.value as AdminUserFilters["sortBy"],
                  }))
                }
              >
                <option value="created_at">Registered date</option>
                <option value="email">Email</option>
              </select>
              <select
                className="h-10 rounded-md border bg-background px-3 text-sm"
                value={draft.sortOrder ?? "desc"}
                onChange={(event) =>
                  setDraft((value) => ({
                    ...value,
                    sortOrder: event.target.value as AdminUserFilters["sortOrder"],
                  }))
                }
              >
                <option value="desc">Descending</option>
                <option value="asc">Ascending</option>
              </select>
            </div>
          </div>
          <div className="mt-3 flex gap-2">
            <Button onClick={applyFilters}>
              <Search className="size-4" />
              Apply filters
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                const reset: AdminUserFilters = { sortBy: "created_at", sortOrder: "desc" };
                setDraft(reset);
                setFilters(reset);
                setCursor(null);
                setHistory([]);
              }}
            >
              Clear
            </Button>
          </div>
        </section>

        {error ? <p className="mt-4 text-sm text-destructive">{error}</p> : null}

        <div className="mt-6">
          <AdminDataTable>
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
                <th className="px-4 py-3">User</th>
                <th className="px-4 py-3">Plan</th>
                <th className="px-4 py-3">Cloud minutes</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Verified</th>
                <th className="px-4 py-3">Latest purchase</th>
                <th className="px-4 py-3">Registered</th>
                <th className="px-4 py-3 text-right">Open</th>
              </tr>
            </thead>
            <tbody>
              {busy ? (
                <tr>
                  <td colSpan={8} className="px-4 py-10 text-center text-muted-foreground">
                    Loading users…
                  </td>
                </tr>
              ) : items.length ? (
                items.map((user) => (
                  <tr key={user.id} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <p className="font-medium">{user.email}</p>
                      <p className="text-xs text-muted-foreground">{user.display_name ?? user.id}</p>
                    </td>
                    <td className="px-4 py-3 uppercase">{user.plan ?? "—"}</td>
                    <td className="px-4 py-3">{user.cloud_minutes_available ?? 0}</td>
                    <td className="px-4 py-3">{accountStatus(user)}</td>
                    <td className="px-4 py-3">{user.email_verified_at ? "Yes" : "No"}</td>
                    <td className="px-4 py-3">{user.latest_purchase_provider ?? "—"}</td>
                    <td className="px-4 py-3">{dateTime(user.created_at)}</td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="outline" asChild>
                        <a href={`/admin/users/${user.id}`}>Open</a>
                      </Button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={8} className="px-4 py-10 text-center text-muted-foreground">
                    No users match these filters.
                  </td>
                </tr>
              )}
            </tbody>
          </AdminDataTable>
          <div className="mt-3 flex justify-end gap-2">
            <Button
              variant="outline"
              disabled={!history.length || busy}
              onClick={() => {
                const nextHistory = history.slice(0, -1);
                setCursor(history.at(-1) ?? null);
                setHistory(nextHistory);
              }}
            >
              Previous
            </Button>
            <Button
              variant="outline"
              disabled={!nextCursor || busy}
              onClick={() => {
                setHistory((value) => [...value, cursor]);
                setCursor(nextCursor);
              }}
            >
              Next
            </Button>
          </div>
        </div>

        <section className="mt-8">
          <h2 className="text-base font-semibold">Privacy requests</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Deletion requests use the existing privacy flow. Completed admin exports also appear here.
          </p>
          <div className="mt-3">
            <AdminDataTable>
              <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3">User</th>
                  <th className="px-4 py-3">Kind</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Requested</th>
                  <th className="px-4 py-3 text-right">Open</th>
                </tr>
              </thead>
              <tbody>
                {privacy.map((request) => (
                  <tr key={request.id} className="border-b last:border-0">
                    <td className="px-4 py-3">{request.email}</td>
                    <td className="px-4 py-3 capitalize">{request.kind}</td>
                    <td className="px-4 py-3 capitalize">{request.status}</td>
                    <td className="px-4 py-3">{dateTime(request.requested_at)}</td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="outline" asChild>
                        <a href={`/admin/users/${request.user_id}`}>Open</a>
                      </Button>
                    </td>
                  </tr>
                ))}
                {!privacy.length ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                      No privacy requests.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </AdminDataTable>
          </div>
        </section>
      </AppShell>
    </AdminMfaGate>
  );
}

type DangerousAction = "lock" | "unlock" | "cancel-deletion" | "perform-deletion";

function StepUpDialog({
  action,
  user,
  open,
  onOpenChange,
  onDone,
}: {
  action: DangerousAction | null;
  user: AdminUser;
  open: boolean;
  onOpenChange: (value: boolean) => void;
  onDone: () => void;
}) {
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setReason("");
      setPassword("");
      setTotp("");
      setError(null);
    }
  }, [open, action]);

  const run = async () => {
    if (!action) return;
    setBusy(true);
    setError(null);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      if (action === "lock") {
        await adminFoundationApi.updateUserStatus(user.id, false, reason, stepUp.token);
      } else if (action === "unlock") {
        await adminFoundationApi.updateUserStatus(user.id, true, reason, stepUp.token);
      } else if (action === "cancel-deletion") {
        await adminFoundationApi.cancelDeletion(user.id, reason, stepUp.token);
      } else {
        await adminFoundationApi.performDeletion(user.id, reason, stepUp.token);
      }
      toast.success("Admin action completed");
      onOpenChange(false);
      onDone();
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Confirm dangerous action</DialogTitle>
          <DialogDescription>
            Re-enter your password, authenticator code, and a reason. This action is permanently audited.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <Input placeholder="Reason" value={reason} onChange={(event) => setReason(event.target.value)} />
          <Input
            type="password"
            placeholder="Password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <Input
            placeholder="Authenticator code"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={totp}
            onChange={(event) => setTotp(event.target.value)}
          />
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={busy}>
            Cancel
          </Button>
          <Button
            onClick={() => void run()}
            disabled={busy || reason.trim().length < 3 || !password || totp.length !== 6}
          >
            Confirm
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export function AdminUserDetailPage({ userId }: { userId: string }) {
  const { user: admin } = useAuth();
  const [detail, setDetail] = useState<AdminUserDetail | null>(null);
  const [view, setView] = useState<AdminViewAsUser | null>(null);
  const [reason, setReason] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [danger, setDanger] = useState<DangerousAction | null>(null);

  const canWrite = admin?.role === "owner" || admin?.role === "support" || admin?.role === "admin";

  const load = async () => {
    setBusy(true);
    setError(null);
    try {
      const data = await adminFoundationApi.getUserDetail(userId);
      setDetail(data);
      setDisplayName(data.user.display_name ?? "");
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
  }, [userId]);

  const runSupportAction = async (
    action: "resend" | "reset" | "logout" | "profile",
  ) => {
    if (reason.trim().length < 3 || !detail) {
      toast.error("Enter a reason first.");
      return;
    }
    try {
      if (action === "resend") {
        await adminFoundationApi.resendVerification(userId, reason);
      } else if (action === "reset") {
        await adminFoundationApi.forcePasswordReset(userId, reason);
      } else if (action === "logout") {
        await adminFoundationApi.forceLogout(userId, reason);
      } else {
        await adminFoundationApi.updateUserProfile(userId, displayName || null, reason);
      }
      toast.success("Support action completed");
      await load();
    } catch (requestError) {
      toast.error(authErrorMessage(requestError));
    }
  };

  const addNote = async () => {
    if (note.trim().length < 1 || reason.trim().length < 3) {
      toast.error("Enter a note and a reason.");
      return;
    }
    try {
      await adminFoundationApi.createUserNote(userId, note, reason);
      setNote("");
      toast.success("Internal note added");
      await load();
    } catch (requestError) {
      toast.error(authErrorMessage(requestError));
    }
  };

  const loadReadOnlyView = async () => {
    if (reason.trim().length < 3) {
      toast.error("Enter a reason before viewing as this user.");
      return;
    }
    try {
      setView(await adminFoundationApi.viewAsUser(userId, reason));
    } catch (requestError) {
      toast.error(authErrorMessage(requestError));
    }
  };

  const exportPrivacy = async () => {
    if (reason.trim().length < 3) {
      toast.error("Enter a reason before exporting user data.");
      return;
    }
    try {
      const exported = await adminFoundationApi.exportPrivacyData(userId, reason);
      downloadText(
        `savestream-user-${userId}-export.json`,
        JSON.stringify(exported, null, 2),
        "application/json",
      );
      toast.success("Privacy export downloaded");
      await load();
    } catch (requestError) {
      toast.error(authErrorMessage(requestError));
    }
  };

  const metrics = useMemo(() => {
    if (!detail) return null;
    return [
      ["Plan", detail.entitlement.plan.toUpperCase()],
      ["Cloud minutes", String(detail.balance.available)],
      ["Channels", String(detail.entitlement.watch_count)],
      ["Recordings", String(detail.recordings.length)],
    ] as const;
  }, [detail]);

  if (busy && !detail) {
    return (
      <AdminMfaGate>
        <AppShell>
          <PageHeader title="User support" subtitle="Loading user…" />
        </AppShell>
      </AdminMfaGate>
    );
  }

  if (!detail) {
    return (
      <AdminMfaGate>
        <AppShell>
          <PageHeader title="User support" />
          <p className="text-sm text-destructive">{error ?? "User could not be loaded."}</p>
        </AppShell>
      </AdminMfaGate>
    );
  }

  const user = detail.user;

  return (
    <AdminMfaGate>
      <AppShell>
        <PageHeader
          title={user.email}
          subtitle={`${user.role} · ${accountStatus(user)} · registered ${dateTime(user.created_at)}`}
          action={
            <Button variant="outline" asChild>
              <a href="/admin/users">Back to users</a>
            </Button>
          }
        />

        <div className="mb-6">
          <AdminGlobalSearch />
        </div>

        {metrics ? (
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {metrics.map(([label, value]) => (
              <AdminMetricCard key={label} label={label} value={value} />
            ))}
          </div>
        ) : null}

        <div className="mt-6 rounded-lg border bg-background p-4">
          <label htmlFor="admin-action-reason" className="text-sm font-medium">
            Reason for support action
          </label>
          <Input
            id="admin-action-reason"
            className="mt-2"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder="Ticket, investigation, or customer request"
          />
          {!canWrite ? (
            <p className="mt-2 text-xs text-muted-foreground">
              Finance access is read-only for user support actions.
            </p>
          ) : null}
        </div>

        <Tabs defaultValue="profile" className="mt-6">
          <TabsList className="h-auto flex-wrap justify-start">
            {[
              ["profile", "Profile"],
              ["plan", "Plan & balance"],
              ["channels", "Channels"],
              ["recordings", "Recordings"],
              ["orders", "Orders"],
              ["ledger", "Ledger"],
              ["sessions", "Devices & sessions"],
              ["notifications", "Notifications"],
              ["notes", "Internal notes"],
              ["audit", "Audit"],
              ["privacy", "Privacy"],
              ["view", "View as user"],
            ] as const).map(([value, label]) => (
              <TabsTrigger key={value} value={value}>
                {label}
              </TabsTrigger>
            ))}
          </TabsList>

          <TabsContent value="profile" className="space-y-4">
            <section className="rounded-lg border bg-background p-5">
              <div className="grid gap-4 md:grid-cols-2">
                <div>
                  <p className="text-xs uppercase text-muted-foreground">User ID</p>
                  <p className="mt-1 font-mono text-sm">{user.id}</p>
                </div>
                <div>
                  <p className="text-xs uppercase text-muted-foreground">Email verified</p>
                  <p className="mt-1 text-sm">{user.email_verified_at ? dateTime(user.email_verified_at) : "No"}</p>
                </div>
              </div>
              <div className="mt-5">
                <label htmlFor="admin-display-name" className="text-sm font-medium">
                  Display name
                </label>
                <div className="mt-2 flex gap-2">
                  <Input
                    id="admin-display-name"
                    value={displayName}
                    onChange={(event) => setDisplayName(event.target.value)}
                    disabled={!canWrite}
                  />
                  {canWrite ? (
                    <Button variant="outline" onClick={() => void runSupportAction("profile")}>
                      Save
                    </Button>
                  ) : null}
                </div>
              </div>
              {canWrite ? (
                <div className="mt-5 flex flex-wrap gap-2">
                  {!user.email_verified_at ? (
                    <Button variant="outline" onClick={() => void runSupportAction("resend")}>
                      Resend verification
                    </Button>
                  ) : null}
                  <Button variant="outline" onClick={() => void runSupportAction("reset")}>
                    Force password reset
                  </Button>
                  <Button variant="outline" onClick={() => void runSupportAction("logout")}>
                    Force logout
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => setDanger(user.is_active ? "lock" : "unlock")}
                  >
                    {user.is_active ? "Lock account" : "Unlock account"}
                  </Button>
                </div>
              ) : null}
            </section>
          </TabsContent>

          <TabsContent value="plan">
            <section className="rounded-lg border bg-background p-5">
              <dl className="grid gap-4 md:grid-cols-3">
                <div><dt className="text-xs uppercase text-muted-foreground">Plan</dt><dd className="mt-1 font-medium uppercase">{detail.entitlement.plan}</dd></div>
                <div><dt className="text-xs uppercase text-muted-foreground">Available</dt><dd className="mt-1 font-medium">{detail.balance.available} minutes</dd></div>
                <div><dt className="text-xs uppercase text-muted-foreground">Reserved</dt><dd className="mt-1 font-medium">{detail.balance.reserved} minutes</dd></div>
                <div><dt className="text-xs uppercase text-muted-foreground">Latest purchase</dt><dd className="mt-1 font-medium">{user.latest_purchase_provider ?? "—"}</dd></div>
                <div><dt className="text-xs uppercase text-muted-foreground">Watch limit</dt><dd className="mt-1 font-medium">{detail.entitlement.max_watches}</dd></div>
                <div><dt className="text-xs uppercase text-muted-foreground">Retention</dt><dd className="mt-1 font-medium">{detail.entitlement.cloud_retention_days} days</dd></div>
              </dl>
            </section>
          </TabsContent>

          <TabsContent value="channels">
            <AdminDataTable>
              <thead className="border-b bg-muted/40"><tr><th className="px-4 py-3">Creator</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Live</th><th className="px-4 py-3">Auto record</th></tr></thead>
              <tbody>{detail.watches.map((item) => <tr key={item.id} className="border-b last:border-0"><td className="px-4 py-3">{item.creator?.username ?? item.source.value}</td><td className="px-4 py-3">{item.status}</td><td className="px-4 py-3">{item.live_status}</td><td className="px-4 py-3">{item.auto_record ? "On" : "Off"}</td></tr>)}</tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="recordings">
            <div className="mb-3 rounded-md border border-warning/30 bg-warning/10 p-3 text-sm">
              Recording metadata only. Playback and download are intentionally unavailable here; D3 requires a separate reasoned, audited access flow.
            </div>
            <AdminDataTable>
              <thead className="border-b bg-muted/40"><tr><th className="px-4 py-3">Recording</th><th className="px-4 py-3">Creator</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Created</th></tr></thead>
              <tbody>{detail.recordings.map((item) => <tr key={item.id} className="border-b last:border-0"><td className="px-4 py-3 font-mono text-xs">{item.id}</td><td className="px-4 py-3">{item.creator?.username ?? item.source.value}</td><td className="px-4 py-3">{item.status}</td><td className="px-4 py-3">{dateTime(item.created_at)}</td></tr>)}</tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="orders">
            <AdminDataTable>
              <thead className="border-b bg-muted/40"><tr><th className="px-4 py-3">Order</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Provider</th><th className="px-4 py-3">Credits</th><th className="px-4 py-3">Created</th></tr></thead>
              <tbody>{detail.payments.map((item) => <tr key={item.id} className="border-b last:border-0"><td className="px-4 py-3 font-mono text-xs">{item.id}</td><td className="px-4 py-3">{item.status}</td><td className="px-4 py-3">{item.provider ?? "—"}</td><td className="px-4 py-3">{item.credits}</td><td className="px-4 py-3">{dateTime(item.created_at)}</td></tr>)}</tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="ledger">
            <AdminDataTable>
              <thead className="border-b bg-muted/40"><tr><th className="px-4 py-3">Type</th><th className="px-4 py-3">Amount</th><th className="px-4 py-3">Balance after</th><th className="px-4 py-3">Reference</th><th className="px-4 py-3">Created</th></tr></thead>
              <tbody>{detail.ledger.map((item) => <tr key={item.id} className="border-b last:border-0"><td className="px-4 py-3">{item.type}</td><td className="px-4 py-3">{item.amount}</td><td className="px-4 py-3">{item.balance_after}</td><td className="px-4 py-3">{item.reference_type}</td><td className="px-4 py-3">{dateTime(item.created_at)}</td></tr>)}</tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="sessions">
            <AdminDataTable>
              <thead className="border-b bg-muted/40"><tr><th className="px-4 py-3">Client</th><th className="px-4 py-3">User agent</th><th className="px-4 py-3">IP hint</th><th className="px-4 py-3">Last seen</th><th className="px-4 py-3">State</th></tr></thead>
              <tbody>{detail.sessions.map((item) => <tr key={item.id} className="border-b last:border-0"><td className="px-4 py-3">{item.client_type}</td><td className="px-4 py-3">{item.user_agent ?? "—"}</td><td className="px-4 py-3">{item.ip_hint ?? "—"}</td><td className="px-4 py-3">{dateTime(item.last_seen_at)}</td><td className="px-4 py-3">{item.revoked_at ? "Revoked" : "Active"}</td></tr>)}</tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="notifications">
            <div className="space-y-3">{detail.notifications.map((item) => <div key={item.id} className="rounded-lg border bg-background p-4"><div className="flex justify-between gap-4"><p className="font-medium">{item.title}</p><span className="text-xs text-muted-foreground">{dateTime(item.created_at)}</span></div><p className="mt-1 text-sm text-muted-foreground">{item.body}</p></div>)}</div>
          </TabsContent>

          <TabsContent value="notes">
            {canWrite ? (
              <section className="mb-4 rounded-lg border bg-background p-4">
                <label htmlFor="admin-note" className="text-sm font-medium">New internal note</label>
                <textarea id="admin-note" className="mt-2 min-h-24 w-full rounded-md border bg-background p-3 text-sm" value={note} onChange={(event) => setNote(event.target.value)} />
                <Button className="mt-3" onClick={() => void addNote()}>Add note</Button>
              </section>
            ) : null}
            <div className="space-y-3">{detail.notes.map((item) => <div key={item.id} className="rounded-lg border bg-background p-4"><p className="text-sm">{item.body}</p><p className="mt-2 text-xs text-muted-foreground">Updated {dateTime(item.updated_at)} · author {item.author_user_id ?? "deleted admin"}</p></div>)}</div>
          </TabsContent>

          <TabsContent value="audit">
            <div className="space-y-3">{detail.audit.map((item) => <div key={item.id} className="rounded-lg border bg-background p-4"><div className="flex justify-between gap-4"><p className="font-mono text-sm">{item.action}</p><span className="text-xs text-muted-foreground">{dateTime(item.created_at)}</span></div><p className="mt-1 text-xs text-muted-foreground">Actor role: {item.actor_role ?? "—"} · Reason: {item.reason ?? "—"}</p></div>)}</div>
          </TabsContent>

          <TabsContent value="privacy" className="space-y-4">
            <section className="rounded-lg border bg-background p-5">
              <h2 className="font-medium">Privacy data</h2>
              <p className="mt-1 text-sm text-muted-foreground">Export uses the existing privacy service and is permanently audited.</p>
              <Button className="mt-3" variant="outline" onClick={() => void exportPrivacy()}>
                <Download className="size-4" />
                Export user data
              </Button>
            </section>
            {user.deletion_requested_at ? (
              <section className="rounded-lg border bg-background p-5">
                <h2 className="font-medium">Pending account deletion</h2>
                <p className="mt-1 text-sm text-muted-foreground">Requested {dateTime(user.deletion_requested_at)}.</p>
                {canWrite ? (
                  <div className="mt-3 flex gap-2">
                    <Button variant="outline" onClick={() => setDanger("cancel-deletion")}>Cancel deletion</Button>
                    <Button onClick={() => setDanger("perform-deletion")}>Perform deletion</Button>
                  </div>
                ) : null}
              </section>
            ) : (
              <p className="text-sm text-muted-foreground">No pending deletion request.</p>
            )}
          </TabsContent>

          <TabsContent value="view">
            <section className="rounded-lg border bg-background p-5">
              <div className="flex items-start gap-3">
                <Eye className="mt-0.5 size-5" />
                <div>
                  <h2 className="font-medium">Read-only user perspective</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    This never creates a user token and never allows actions. Opening it is audited with your reason.
                  </p>
                </div>
              </div>
              <Button className="mt-4" variant="outline" onClick={() => void loadReadOnlyView()}>
                View as user
              </Button>
            </section>
            {view ? (
              <div className="mt-4">
                <div className="rounded-md border border-warning/30 bg-warning/10 p-3 text-sm font-medium">
                  Viewing as {view.user.email} (read-only)
                </div>
                <div className="mt-4 grid gap-3 sm:grid-cols-3">
                  <AdminMetricCard label="Plan" value={view.entitlement.plan.toUpperCase()} />
                  <AdminMetricCard label="Cloud minutes" value={view.balance.available} />
                  <AdminMetricCard label="Channels" value={view.watches.length} />
                </div>
                <p className="mt-4 text-sm text-muted-foreground">
                  Recording metadata is visible. Playback and download are not exposed by this D1 view.
                </p>
              </div>
            ) : null}
          </TabsContent>
        </Tabs>

        {error ? <p className="mt-4 text-sm text-destructive">{error}</p> : null}

        <StepUpDialog
          action={danger}
          user={user}
          open={danger !== null}
          onOpenChange={(open) => !open && setDanger(null)}
          onDone={() => void load()}
        />
      </AppShell>
    </AdminMfaGate>
  );
}
