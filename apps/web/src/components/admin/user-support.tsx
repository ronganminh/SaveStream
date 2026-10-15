import { formatAdminDateTime } from "@/lib/formatters";
import { Fragment, useEffect, useState, type ReactNode } from "react";
import { Download, Eye, Gift, Search } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, AvatarCircle, PageHeader } from "@/components/app-components";
import { initials } from "@/repositories/mappers/channel";
import { describeUserAgent } from "@/lib/user-agent";
import {
  AdminBadge,
  AdminCard,
  AdminDataTable,
  AdminGlobalSearch,
  AdminMfaGate,
  AdminMetricCard,
  AdminTabsList,
  AdminTabsTrigger,
  AdminUserStatusBadge,
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
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Tabs, TabsContent } from "@/components/ui/tabs";
import {
  adminFoundationApi,
  type AdminAccountStatus,
  type AdminPrivacyRequest,
  type AdminUser,
  type AdminUserDetail,
  type AdminUserFilters,
  type AdminViewAsUser,
} from "@/repositories/admin-api";

function CreatorCell({
  username,
  avatarUrl,
}: {
  username: string;
  avatarUrl?: string | null | undefined;
}) {
  return (
    <span className="flex items-center gap-2">
      <AvatarCircle src={avatarUrl} initials={initials(username.replace(/^@/, ""))} size="xs" />
      <span className="truncate">{username}</span>
    </span>
  );
}

function accountStatus(user: AdminUser) {
  if (user.deletion_requested_at) return "Pending deletion";
  return user.is_active ? "Active" : "Locked";
}

function dateTime(value: string | null | undefined) {
  if (!value) return "—";
  return formatAdminDateTime(value);
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
  const [quickLook, setQuickLook] = useState<AdminUser | null>(null);

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

        <section className="rounded-[16px] border bg-surface p-4">
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
                setDraft((value) => ({
                  ...value,
                  plan: event.target.value as AdminUserFilters["plan"],
                }))
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
            <thead>
              <tr className="border-b">
                <th className="px-4 py-3">User</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Plan</th>
                <th className="px-4 py-3 text-right">Cloud minutes</th>
                <th className="px-4 py-3">Latest purchase</th>
                <th className="px-4 py-3">Registered</th>
                <th className="px-4 py-3 text-right">
                  <span className="sr-only">Open</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {busy ? (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-muted-foreground">
                    Loading users…
                  </td>
                </tr>
              ) : items.length ? (
                items.map((user) => (
                  <tr
                    key={user.id}
                    className={`border-b last:border-0 ${quickLook?.id === user.id ? "bg-primary-subtle/60" : ""}`}
                  >
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() => setQuickLook(user)}
                        className="flex items-center gap-2.5 text-left"
                      >
                        <AvatarCircle
                          initials={initials(user.display_name || user.email)}
                          size="sm"
                        />
                        <span className="min-w-0">
                          <span className="block truncate font-bold">
                            {user.display_name || user.email}
                          </span>
                          <span className="block truncate text-xs text-muted-foreground">
                            {user.email}
                          </span>
                        </span>
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <AdminUserStatusBadge user={user} />
                    </td>
                    <td className="px-4 py-3 uppercase">{user.plan ?? "—"}</td>
                    <td className="px-4 py-3 text-right font-mono">
                      {user.cloud_minutes_available ?? 0}
                    </td>
                    <td className="px-4 py-3">{user.latest_purchase_provider ?? "—"}</td>
                    <td className="px-4 py-3 text-muted-foreground">{dateTime(user.created_at)}</td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="ghost" asChild>
                        <a href={`/admin/users/${user.id}`}>Open</a>
                      </Button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-muted-foreground">
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
          <h2 className="text-[17px] font-bold tracking-[-.01em]">Privacy requests</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Deletion requests use the existing privacy flow. Completed admin exports also appear
            here.
          </p>
          <div className="mt-3">
            <AdminDataTable>
              <thead>
                <tr className="border-b">
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

        <UserQuickLook user={quickLook} onClose={() => setQuickLook(null)} />
      </AppShell>
    </AdminMfaGate>
  );
}

function hoursLabel(minutes: number) {
  return `${(minutes / 60).toFixed(1)} h`;
}

/** Right-side drawer with the essentials of one user, from the users table. */
function UserQuickLook({ user, onClose }: { user: AdminUser | null; onClose: () => void }) {
  const [detail, setDetail] = useState<AdminUserDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    setDetail(null);
    setError(null);
    adminFoundationApi
      .getUserDetail(user.id)
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch((requestError: unknown) => {
        if (!cancelled) setError(authErrorMessage(requestError));
      });
    return () => {
      cancelled = true;
    };
  }, [user]);

  return (
    <Sheet open={user !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-[440px]">
        {user ? (
          <div className="flex flex-col gap-5">
            <SheetHeader className="space-y-0 p-0 text-left">
              <p className="font-mono text-xs font-bold text-muted-foreground">{user.id}</p>
              <div className="mt-3 flex items-center gap-3.5">
                <AvatarCircle initials={initials(user.display_name || user.email)} size="lg" />
                <div className="min-w-0">
                  <SheetTitle className="truncate text-xl font-extrabold">
                    {user.display_name || user.email}
                  </SheetTitle>
                  <SheetDescription className="truncate">{user.email}</SheetDescription>
                  <div className="mt-1.5">
                    <AdminUserStatusBadge user={user} />
                  </div>
                </div>
              </div>
            </SheetHeader>
            <div className="grid grid-cols-3 gap-2.5">
              {[
                ["Balance", detail ? hoursLabel(detail.balance.available) : "…"],
                ["Channels", detail ? String(detail.entitlement.watch_count) : "…"],
                ["Recordings", detail ? String(detail.recordings.length) : "…"],
              ].map(([label, value]) => (
                <div key={label} className="rounded-[12px] bg-surface-2 p-3">
                  <p className="text-xs font-bold text-muted-foreground">{label}</p>
                  <p className="mt-0.5 font-mono font-bold">{value}</p>
                </div>
              ))}
            </div>
            <dl className="grid grid-cols-[120px_1fr] gap-y-2 text-sm">
              <dt className="text-muted-foreground">Registered</dt>
              <dd>{dateTime(user.created_at)}</dd>
              <dt className="text-muted-foreground">Email verified</dt>
              <dd>{user.email_verified_at ? dateTime(user.email_verified_at) : "No"}</dd>
              <dt className="text-muted-foreground">Latest purchase</dt>
              <dd>{user.latest_purchase_provider ?? "—"}</dd>
              <dt className="text-muted-foreground">Role</dt>
              <dd className="capitalize">{user.role}</dd>
            </dl>
            {error ? <p className="text-sm text-destructive">{error}</p> : null}
            {detail?.watches.length ? (
              <div>
                <p className="mb-2 text-sm font-bold">Channels</p>
                <div className="overflow-hidden rounded-[12px] border">
                  {detail.watches.slice(0, 5).map((item) => (
                    <div
                      key={item.id}
                      className="flex items-center gap-2 border-b px-3 py-2.5 text-sm last:border-0"
                    >
                      <span className="min-w-0 flex-1 font-bold">
                        <CreatorCell
                          username={`@${item.creator?.username ?? item.source.value}`}
                          avatarUrl={item.creator?.avatar_url}
                        />
                      </span>
                      <AdminBadge tone={item.status === "active" ? "success" : "neutral"}>
                        {item.status}
                      </AdminBadge>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            {detail?.payments.length ? (
              <div>
                <p className="mb-2 text-sm font-bold">Recent orders</p>
                <div className="overflow-hidden rounded-[12px] border">
                  {detail.payments.slice(0, 3).map((item) => (
                    <div
                      key={item.id}
                      className="flex items-center gap-2 border-b px-3 py-2.5 last:border-0"
                    >
                      <span className="min-w-0 flex-1 truncate font-mono text-xs">{item.id}</span>
                      <AdminBadge tone={item.status === "paid" ? "success" : "neutral"}>
                        {item.status}
                      </AdminBadge>
                      <span className="font-mono text-sm">{item.credits} cr</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            <div className="flex flex-col gap-2 border-t pt-4">
              <Button asChild>
                <a href={`/admin/users/${user.id}`}>Open full profile</a>
              </Button>
              <p className="text-xs text-muted-foreground">
                Support actions need a reason and are recorded in the audit log.
              </p>
            </div>
          </div>
        ) : null}
      </SheetContent>
    </Sheet>
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
            Re-enter your password, authenticator code, and a reason. This action is permanently
            audited.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <Input
            placeholder="Reason"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          />
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

type ReasonRequest = {
  title: string;
  description: string;
  audit: string;
  confirmLabel: string;
  danger?: boolean;
  run: (reason: string) => Promise<void>;
};

const MIN_REASON_LENGTH = 10;

const accountStatusCopy: Record<
  AdminAccountStatus,
  { title: string; description: string; confirm: string; audit: string; danger: boolean }
> = {
  suspended: {
    title: "Suspend this account?",
    description:
      "Signs the user out, pauses channel monitoring and stops active recordings. Nothing is deleted. The user is emailed the reason and can appeal to support@savestream.online.",
    confirm: "Suspend account",
    audit: "admin.user.suspended",
    danger: true,
  },
  terminated: {
    title: "Terminate this account?",
    description:
      "Permanent: the user can no longer sign in and monitoring stops. Recordings and billing records are kept and are not deleted by this action. The user is emailed the reason.",
    confirm: "Terminate account",
    audit: "admin.user.terminated",
    danger: true,
  },
  active: {
    title: "Reinstate this account?",
    description:
      "The user can sign in again. Channels paused by the suspension resume monitoring. The user is emailed.",
    confirm: "Reinstate account",
    audit: "admin.user.reinstated",
    danger: false,
  },
};

/** Suspend / reinstate / terminate: reason (shown to the user), optional
 * case reference, and password + authenticator step-up. */
function AccountStatusDialog({
  status,
  user,
  onClose,
  onDone,
}: {
  status: AdminAccountStatus | null;
  user: AdminUser;
  onClose: () => void;
  onDone: () => void;
}) {
  const [reason, setReason] = useState("");
  const [reference, setReference] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (status) {
      setReason("");
      setReference(user.account_status_reference ?? "");
      setPassword("");
      setTotp("");
      setError(null);
    }
  }, [status]);

  const copy = status ? accountStatusCopy[status] : null;

  const run = async () => {
    if (!status) return;
    setBusy(true);
    setError(null);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      await adminFoundationApi.changeAccountStatus(
        user.id,
        status,
        reason.trim(),
        reference.trim() || null,
        stepUp.token,
      );
      toast.success("Account status updated");
      onClose();
      onDone();
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={status !== null} onOpenChange={(open) => !open && !busy && onClose()}>
      <DialogContent className="max-w-[520px]">
        <DialogHeader>
          <DialogTitle>{copy?.title}</DialogTitle>
          <DialogDescription>{copy?.description}</DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1.5">
            <label htmlFor="account-status-reason" className="text-sm font-bold">
              Reason <span className="text-destructive">*</span>
            </label>
            <textarea
              id="account-status-reason"
              className="min-h-[84px] w-full rounded-[12px] border bg-surface p-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              placeholder={
                status === "active"
                  ? "e.g. Appeal accepted: the owner showed proof of authorization."
                  : "e.g. Recording LIVEs without the channel owner's permission (AUP)."
              }
              value={reason}
              onChange={(event) => setReason(event.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              {status === "active"
                ? "Stored in the audit log."
                : "Shown to the user on the sign-in page and in the email, and stored in the audit log."}{" "}
              Minimum {MIN_REASON_LENGTH} characters.
            </p>
          </div>
          <div className="space-y-1.5">
            <label htmlFor="account-status-reference" className="text-sm font-bold">
              Case reference <span className="font-normal text-muted-foreground">(optional)</span>
            </label>
            <Input
              id="account-status-reference"
              placeholder="e.g. SR-1040"
              maxLength={64}
              value={reference}
              onChange={(event) => setReference(event.target.value)}
            />
          </div>
          <Input
            type="password"
            placeholder="Your password"
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
        <DialogFooter className="items-center sm:justify-between">
          <span className="font-mono text-xs text-muted-foreground">audit: {copy?.audit}</span>
          <div className="flex gap-2">
            <Button variant="ghost" onClick={onClose} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={copy?.danger ? "destructive" : "default"}
              disabled={
                busy || reason.trim().length < MIN_REASON_LENGTH || !password || totp.length !== 6
              }
              onClick={() => void run()}
            >
              {busy ? "Working…" : copy?.confirm}
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/** Every support action asks for a reason; it is stored in the audit log. */
function ReasonDialog({
  request,
  onClose,
}: {
  request: ReasonRequest | null;
  onClose: () => void;
}) {
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (request) setReason("");
  }, [request]);

  const confirm = async () => {
    if (!request) return;
    setBusy(true);
    try {
      await request.run(reason.trim());
      onClose();
    } catch (requestError) {
      toast.error(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={request !== null} onOpenChange={(open) => !open && !busy && onClose()}>
      <DialogContent className="max-w-[500px]">
        <DialogHeader>
          <DialogTitle>{request?.title}</DialogTitle>
          <DialogDescription>{request?.description}</DialogDescription>
        </DialogHeader>
        <div className="space-y-1.5">
          <label htmlFor="admin-reason" className="text-sm font-bold">
            Reason <span className="text-destructive">*</span>
          </label>
          <textarea
            id="admin-reason"
            className="min-h-[84px] w-full rounded-[12px] border bg-surface p-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            placeholder="Required. Stored in the audit log."
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          />
          <p className="text-xs text-muted-foreground">
            Required · minimum {MIN_REASON_LENGTH} characters
          </p>
        </div>
        <DialogFooter className="items-center sm:justify-between">
          <span className="font-mono text-xs text-muted-foreground">audit: {request?.audit}</span>
          <div className="flex gap-2">
            <Button variant="ghost" onClick={onClose} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={request?.danger ? "destructive" : "default"}
              disabled={busy || reason.trim().length < MIN_REASON_LENGTH}
              onClick={() => void confirm()}
            >
              {busy ? "Working…" : (request?.confirmLabel ?? "Confirm")}
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

const userTabs = [
  ["profile", "Profile"],
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
] as const;

function KeyValues({ rows }: { rows: ReadonlyArray<readonly [string, ReactNode]> }) {
  return (
    <dl className="grid grid-cols-[150px_1fr] gap-x-4 gap-y-2.5 text-sm">
      {rows.map(([label, value]) => (
        <Fragment key={label}>
          <dt className="text-muted-foreground">{label}</dt>
          <dd className="min-w-0 break-words">{value}</dd>
        </Fragment>
      ))}
    </dl>
  );
}

function ledgerLabel(type: string) {
  return type.replace(/_/g, " ").replace(/^\w/, (letter) => letter.toUpperCase());
}

export function AdminUserDetailPage({ userId }: { userId: string }) {
  const { user: admin } = useAuth();
  const [detail, setDetail] = useState<AdminUserDetail | null>(null);
  const [view, setView] = useState<AdminViewAsUser | null>(null);
  const [displayName, setDisplayName] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [danger, setDanger] = useState<DangerousAction | null>(null);
  const [reasonRequest, setReasonRequest] = useState<ReasonRequest | null>(null);
  const [statusChange, setStatusChange] = useState<AdminAccountStatus | null>(null);

  const canWrite = admin?.role === "owner" || admin?.role === "support" || admin?.role === "admin";
  const canGrant = admin?.role === "owner" || admin?.role === "finance" || admin?.role === "admin";

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

  const supportAction = (action: "resend" | "reset" | "logout" | "profile") => {
    const name = detail?.user.display_name || detail?.user.email || "this user";
    const copy = {
      resend: {
        title: "Resend the verification email?",
        description: `${name} gets a new verification link.`,
        audit: "user.resend_verification",
        confirmLabel: "Resend",
      },
      reset: {
        title: "Send a password reset email?",
        description: `${name} gets a reset link and must choose a new password.`,
        audit: "user.force_password_reset",
        confirmLabel: "Send reset",
      },
      logout: {
        title: "Sign out all sessions?",
        description: "Every device is signed out. Active recordings keep running.",
        audit: "user.force_logout",
        confirmLabel: "Sign out all",
      },
      profile: {
        title: "Save the display name?",
        description: `The display name changes to “${displayName || "(empty)"}”.`,
        audit: "user.profile_update",
        confirmLabel: "Save",
      },
    }[action];
    setReasonRequest({
      ...copy,
      run: async (reason) => {
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
      },
    });
  };

  const addNote = () => {
    if (!note.trim()) {
      toast.error("Write the note first.");
      return;
    }
    setReasonRequest({
      title: "Add internal note?",
      description: "Internal notes are visible to admins only.",
      audit: "user.note_create",
      confirmLabel: "Add note",
      run: async (reason) => {
        await adminFoundationApi.createUserNote(userId, note, reason);
        setNote("");
        toast.success("Internal note added");
        await load();
      },
    });
  };

  const loadReadOnlyView = () =>
    setReasonRequest({
      title: "View as this user?",
      description: "Opens a read-only view. Opening it is audited with your reason.",
      audit: "user.view_as",
      confirmLabel: "View as user",
      run: async (reason) => {
        setView(await adminFoundationApi.viewAsUser(userId, reason));
      },
    });

  const exportPrivacy = () =>
    setReasonRequest({
      title: "Export this user's data?",
      description: "Downloads the privacy export as JSON. The export is permanently audited.",
      audit: "privacy.export",
      confirmLabel: "Export",
      run: async (reason) => {
        const exported = await adminFoundationApi.exportPrivacyData(userId, reason);
        downloadText(
          `savestream-user-${userId}-export.json`,
          JSON.stringify(exported, null, 2),
          "application/json",
        );
        toast.success("Privacy export downloaded");
        await load();
      },
    });

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
  const name = user.display_name || user.email;
  const counts: Partial<Record<(typeof userTabs)[number][0], number>> = {
    channels: detail.watches.length,
    recordings: detail.recordings.length,
    orders: detail.payments.length,
    sessions: detail.sessions.filter((item) => !item.revoked_at).length,
  };

  return (
    <AdminMfaGate>
      <AppShell>
        <nav
          className="mb-4 flex items-center gap-2 text-sm text-muted-foreground"
          aria-label="Breadcrumb"
        >
          <a href="/admin/users" className="hover:text-foreground">
            Users
          </a>
          <span aria-hidden="true">/</span>
          <span className="truncate text-foreground" aria-current="page">
            {name}
          </span>
        </nav>

        <section
          className="flex flex-wrap items-center gap-5 rounded-[18px] border bg-surface p-6 shadow-card"
          aria-label="User summary"
        >
          <AvatarCircle initials={initials(name)} size="xl" />
          <div className="min-w-[240px] flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-[26px] font-extrabold leading-tight tracking-[-.025em]">
                {name}
              </h1>
              <AdminUserStatusBadge user={user} />
              {user.email_verified_at ? <AdminBadge>Email verified</AdminBadge> : null}
              {user.role !== "user" ? <AdminBadge tone="accent">{user.role}</AdminBadge> : null}
            </div>
            <p className="mt-1 text-sm text-muted-foreground">
              {user.email} · <span className="font-mono">{user.id}</span> · registered{" "}
              {dateTime(user.created_at)}
              {user.latest_purchase_provider
                ? ` · latest purchase ${user.latest_purchase_provider}`
                : ""}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            {canGrant ? (
              <Button asChild>
                <a href="/admin/payments">
                  <Gift className="size-4" />
                  Grant minutes
                </a>
              </Button>
            ) : null}
            {canWrite ? (
              <>
                {!user.email_verified_at ? (
                  <Button variant="outline" onClick={() => supportAction("resend")}>
                    Resend verification
                  </Button>
                ) : null}
                <Button variant="outline" onClick={() => supportAction("reset")}>
                  Force password reset
                </Button>
                <Button variant="outline" onClick={() => supportAction("logout")}>
                  Force logout
                </Button>
                <Button
                  variant="outline"
                  className={
                    user.is_active
                      ? "border-destructive/40 text-destructive hover:bg-destructive/10 hover:text-destructive"
                      : ""
                  }
                  onClick={() => setDanger(user.is_active ? "lock" : "unlock")}
                >
                  {user.is_active ? "Lock account" : "Unlock account"}
                </Button>
                {user.role === "user" && (user.account_status ?? "active") === "active" ? (
                  <>
                    <Button
                      variant="outline"
                      className="border-destructive/40 text-destructive hover:bg-destructive/10 hover:text-destructive"
                      onClick={() => setStatusChange("suspended")}
                    >
                      Suspend
                    </Button>
                    <Button
                      variant="outline"
                      className="border-destructive/40 text-destructive hover:bg-destructive/10 hover:text-destructive"
                      onClick={() => setStatusChange("terminated")}
                    >
                      Terminate
                    </Button>
                  </>
                ) : null}
                {user.account_status === "suspended" ? (
                  <>
                    <Button variant="outline" onClick={() => setStatusChange("active")}>
                      Reinstate
                    </Button>
                    <Button
                      variant="outline"
                      className="border-destructive/40 text-destructive hover:bg-destructive/10 hover:text-destructive"
                      onClick={() => setStatusChange("terminated")}
                    >
                      Terminate
                    </Button>
                  </>
                ) : null}
              </>
            ) : null}
          </div>
          {!canWrite ? (
            <p className="w-full text-xs text-muted-foreground">
              Finance access is read-only for user support actions.
            </p>
          ) : null}
        </section>

        {user.account_status && user.account_status !== "active" ? (
          <div
            role="status"
            className="mt-4 rounded-[14px] border border-destructive/30 bg-destructive/5 p-4 text-sm"
          >
            <p className="font-bold text-destructive">
              Account {user.account_status}
              {user.account_status_changed_at
                ? ` · ${dateTime(user.account_status_changed_at)}`
                : ""}
              {user.account_status_reference ? ` · ${user.account_status_reference}` : ""}
            </p>
            {user.account_status_reason ? (
              <p className="mt-1 text-foreground">{user.account_status_reason}</p>
            ) : null}
            <p className="mt-1 text-xs text-muted-foreground">
              Monitoring is paused and the user cannot sign in. Data is kept. Appeals go to
              support@savestream.online.
            </p>
          </div>
        ) : null}

        <div className="mt-5">
          <AdminGlobalSearch />
        </div>

        <Tabs defaultValue="profile" className="mt-5">
          <AdminTabsList label="User sections">
            {userTabs.map(([value, label]) => (
              <AdminTabsTrigger key={value} value={value} count={counts[value]}>
                {label}
              </AdminTabsTrigger>
            ))}
          </AdminTabsList>

          <TabsContent value="profile" className="mt-5">
            <div className="grid items-start gap-5 xl:grid-cols-2">
              <AdminCard title="Profile & plan">
                <KeyValues
                  rows={[
                    ["User ID", <span className="font-mono text-xs">{user.id}</span>],
                    [
                      "Email verified",
                      user.email_verified_at ? dateTime(user.email_verified_at) : "No",
                    ],
                    ["Plan", <span className="uppercase">{detail.entitlement.plan}</span>],
                    ["Has purchased", detail.entitlement.has_purchased ? "Yes" : "No"],
                    ["Latest purchase", user.latest_purchase_provider ?? "—"],
                    [
                      "Channel limit",
                      `${detail.entitlement.watch_count} of ${detail.entitlement.max_watches}`,
                    ],
                    [
                      "Concurrent recordings",
                      String(detail.entitlement.max_concurrent_cloud_recordings),
                    ],
                    ["Retention", `${detail.entitlement.cloud_retention_days} days`],
                  ]}
                />
                <div className="mt-5 border-t pt-4">
                  <label htmlFor="admin-display-name" className="text-sm font-bold">
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
                      <Button
                        variant="outline"
                        disabled={displayName === (user.display_name ?? "")}
                        onClick={() => supportAction("profile")}
                      >
                        Save
                      </Button>
                    ) : null}
                  </div>
                </div>
              </AdminCard>

              <AdminCard
                title="Cloud minutes"
                action={
                  <a
                    href="/admin/payments"
                    className="text-sm font-bold text-accent-ink hover:underline"
                  >
                    Full ledger
                  </a>
                }
              >
                <div className="flex flex-wrap gap-6">
                  {[
                    ["Available", detail.balance.available],
                    ["On hold", detail.balance.reserved],
                    ["Posted", detail.balance.posted],
                  ].map(([label, value]) => (
                    <div key={label}>
                      <p className="text-[13px] font-semibold text-muted-foreground">{label}</p>
                      <p className="font-mono text-[24px] font-bold tracking-[-.02em]">
                        {value}{" "}
                        <span className="text-sm font-semibold text-muted-foreground">min</span>
                      </p>
                    </div>
                  ))}
                </div>
                {detail.ledger.length ? (
                  <div className="mt-4 overflow-hidden rounded-[12px] border">
                    {detail.ledger.slice(0, 5).map((item) => (
                      <div
                        key={item.id}
                        className="flex items-center gap-3 border-b px-3.5 py-2.5 last:border-0"
                      >
                        <span className="min-w-0 flex-1 truncate text-sm">
                          {ledgerLabel(item.type)}
                        </span>
                        <span className="font-mono text-xs text-muted-foreground">
                          {dateTime(item.created_at)}
                        </span>
                        <b className={`font-mono text-sm ${item.amount > 0 ? "text-success" : ""}`}>
                          {item.amount > 0 ? "+" : ""}
                          {item.amount}
                        </b>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="mt-4 text-sm text-muted-foreground">No ledger entries yet.</p>
                )}
              </AdminCard>
            </div>
          </TabsContent>

          <TabsContent value="channels" className="mt-5">
            <AdminDataTable>
              <thead>
                <tr className="border-b">
                  <th className="px-4 py-3">Creator</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Live</th>
                  <th className="px-4 py-3">Auto record</th>
                  <th className="px-4 py-3">Ownership</th>
                  <th className="px-4 py-3">Added</th>
                </tr>
              </thead>
              <tbody>
                {detail.watches.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3 font-bold">
                      <CreatorCell
                        username={item.creator?.username ?? item.source.value}
                        avatarUrl={item.creator?.avatar_url}
                      />
                    </td>
                    <td className="px-4 py-3">
                      <AdminBadge tone={item.status === "active" ? "success" : "neutral"} dot>
                        {item.status}
                      </AdminBadge>
                    </td>
                    <td className="px-4 py-3">{item.live_status}</td>
                    <td className="px-4 py-3">{item.auto_record ? "On" : "Off"}</td>
                    <td className="px-4 py-3">
                      {item.owner_attested_at ? (
                        <span title={`Confirmed ${dateTime(item.owner_attested_at)}`}>
                          <AdminBadge tone="success">
                            Confirmed {dateTime(item.owner_attested_at)}
                          </AdminBadge>
                        </span>
                      ) : (
                        <span className="text-muted-foreground">Not confirmed</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{dateTime(item.created_at)}</td>
                  </tr>
                ))}
                {!detail.watches.length ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-muted-foreground">
                      No channels.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="recordings" className="mt-5">
            <div className="mb-3 rounded-[12px] border border-warning/30 bg-warning-subtle px-4 py-3 text-sm">
              Recording metadata only. Playback and download are intentionally unavailable here; D3
              requires a separate reasoned, audited access flow.
            </div>
            <AdminDataTable>
              <thead>
                <tr className="border-b">
                  <th className="px-4 py-3">Recording</th>
                  <th className="px-4 py-3">Creator</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Created</th>
                </tr>
              </thead>
              <tbody>
                {detail.recordings.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3 font-mono text-xs">
                      <a
                        className="text-accent-ink hover:underline"
                        href={`/admin/jobs/${item.id}`}
                      >
                        {item.id}
                      </a>
                    </td>
                    <td className="px-4 py-3">
                      <CreatorCell
                        username={item.creator?.username ?? item.source.value}
                        avatarUrl={item.creator?.avatar_url}
                      />
                    </td>
                    <td className="px-4 py-3">
                      <AdminBadge
                        tone={
                          item.status === "completed"
                            ? "success"
                            : item.status === "failed"
                              ? "danger"
                              : "neutral"
                        }
                        dot
                      >
                        {item.status}
                      </AdminBadge>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{dateTime(item.created_at)}</td>
                  </tr>
                ))}
                {!detail.recordings.length ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-muted-foreground">
                      No recordings.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="orders" className="mt-5">
            <AdminDataTable>
              <thead>
                <tr className="border-b">
                  <th className="px-4 py-3">Order</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Provider</th>
                  <th className="px-4 py-3 text-right">Credits</th>
                  <th className="px-4 py-3">Created</th>
                </tr>
              </thead>
              <tbody>
                {detail.payments.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3 font-mono text-xs">{item.id}</td>
                    <td className="px-4 py-3">
                      <AdminBadge
                        tone={
                          item.status === "paid"
                            ? "success"
                            : item.status === "refunded"
                              ? "warning"
                              : "neutral"
                        }
                        dot
                      >
                        {item.status}
                      </AdminBadge>
                    </td>
                    <td className="px-4 py-3">{item.provider ?? "—"}</td>
                    <td className="px-4 py-3 text-right font-mono">{item.credits}</td>
                    <td className="px-4 py-3 text-muted-foreground">{dateTime(item.created_at)}</td>
                  </tr>
                ))}
                {!detail.payments.length ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                      No orders.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="ledger" className="mt-5">
            <AdminDataTable>
              <thead>
                <tr className="border-b">
                  <th className="px-4 py-3">Type</th>
                  <th className="px-4 py-3 text-right">Amount</th>
                  <th className="px-4 py-3 text-right">Balance after</th>
                  <th className="px-4 py-3">Reference</th>
                  <th className="px-4 py-3">Created</th>
                </tr>
              </thead>
              <tbody>
                {detail.ledger.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3">{ledgerLabel(item.type)}</td>
                    <td
                      className={`px-4 py-3 text-right font-mono ${item.amount > 0 ? "text-success" : ""}`}
                    >
                      {item.amount > 0 ? "+" : ""}
                      {item.amount}
                    </td>
                    <td className="px-4 py-3 text-right font-mono">{item.balance_after}</td>
                    <td className="px-4 py-3">{item.reference_type}</td>
                    <td className="px-4 py-3 text-muted-foreground">{dateTime(item.created_at)}</td>
                  </tr>
                ))}
                {!detail.ledger.length ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                      No ledger entries.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="sessions" className="mt-5">
            <AdminDataTable>
              <thead>
                <tr className="border-b">
                  <th className="px-4 py-3">Device</th>
                  <th className="px-4 py-3">IP hint</th>
                  <th className="px-4 py-3">Last seen</th>
                  <th className="px-4 py-3">State</th>
                </tr>
              </thead>
              <tbody>
                {detail.sessions.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <p className="font-bold">{describeUserAgent(item.user_agent)}</p>
                      <p className="text-xs text-muted-foreground">{item.client_type}</p>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs">{item.ip_hint ?? "—"}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {dateTime(item.last_seen_at)}
                    </td>
                    <td className="px-4 py-3">
                      {item.revoked_at ? (
                        <AdminBadge>Revoked</AdminBadge>
                      ) : (
                        <AdminBadge tone="success" dot>
                          Active
                        </AdminBadge>
                      )}
                    </td>
                  </tr>
                ))}
                {!detail.sessions.length ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-muted-foreground">
                      No sessions.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </AdminDataTable>
          </TabsContent>

          <TabsContent value="notifications" className="mt-5">
            <div className="overflow-hidden rounded-[16px] border bg-surface">
              {detail.notifications.map((item) => (
                <div key={item.id} className="border-b px-5 py-4 last:border-0">
                  <div className="flex justify-between gap-4">
                    <p className="font-bold">{item.title}</p>
                    <span className="text-xs text-muted-foreground">
                      {dateTime(item.created_at)}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">{item.body}</p>
                </div>
              ))}
              {!detail.notifications.length ? (
                <p className="px-5 py-8 text-center text-sm text-muted-foreground">
                  No notifications.
                </p>
              ) : null}
            </div>
          </TabsContent>

          <TabsContent value="notes" className="mt-5 space-y-4">
            {canWrite ? (
              <AdminCard title="New internal note">
                <label htmlFor="admin-note" className="sr-only">
                  New internal note
                </label>
                <textarea
                  id="admin-note"
                  className="min-h-24 w-full rounded-[12px] border bg-surface p-3 text-sm"
                  value={note}
                  onChange={(event) => setNote(event.target.value)}
                />
                <Button className="mt-3" onClick={addNote}>
                  Add note
                </Button>
              </AdminCard>
            ) : null}
            <div className="space-y-3">
              {detail.notes.map((item) => (
                <div key={item.id} className="rounded-[16px] border bg-surface p-4">
                  <p className="text-sm">{item.body}</p>
                  <p className="mt-2 text-xs text-muted-foreground">
                    Updated {dateTime(item.updated_at)} · author{" "}
                    {item.author_user_id ?? "deleted admin"}
                  </p>
                </div>
              ))}
            </div>
          </TabsContent>

          <TabsContent value="audit" className="mt-5">
            <div className="overflow-hidden rounded-[16px] border bg-surface">
              {detail.audit.map((item) => (
                <div
                  key={item.id}
                  className="flex flex-wrap items-center gap-3 border-b px-4 py-3 last:border-0"
                >
                  <AdminBadge tone="accent">
                    <span className="font-mono">{item.action}</span>
                  </AdminBadge>
                  <span className="min-w-0 flex-1 text-sm">
                    {item.actor_role ?? "system"} · {item.reason ?? "—"}
                  </span>
                  <span className="font-mono text-xs text-muted-foreground">
                    {dateTime(item.created_at)}
                  </span>
                </div>
              ))}
              {!detail.audit.length ? (
                <p className="px-5 py-8 text-center text-sm text-muted-foreground">
                  No audit entries.
                </p>
              ) : null}
            </div>
          </TabsContent>

          <TabsContent value="privacy" className="mt-5 space-y-4">
            <AdminCard
              title="Privacy data"
              description="Export uses the existing privacy service and is permanently audited."
            >
              <Button variant="outline" onClick={exportPrivacy}>
                <Download className="size-4" />
                Export user data
              </Button>
            </AdminCard>
            {user.deletion_requested_at ? (
              <AdminCard
                title="Pending account deletion"
                description={`Requested ${dateTime(user.deletion_requested_at)}.`}
              >
                {canWrite ? (
                  <div className="flex gap-2">
                    <Button variant="outline" onClick={() => setDanger("cancel-deletion")}>
                      Cancel deletion
                    </Button>
                    <Button variant="destructive" onClick={() => setDanger("perform-deletion")}>
                      Perform deletion
                    </Button>
                  </div>
                ) : (
                  <p className="text-sm text-muted-foreground">
                    Only Support and Owner admins can act on deletion requests.
                  </p>
                )}
              </AdminCard>
            ) : (
              <p className="text-sm text-muted-foreground">No pending deletion request.</p>
            )}
          </TabsContent>

          <TabsContent value="view" className="mt-5">
            <AdminCard>
              <div className="flex items-start gap-3">
                <span className="grid size-10 shrink-0 place-items-center rounded-[12px] bg-primary-subtle text-accent-ink">
                  <Eye className="size-5" />
                </span>
                <div>
                  <h2 className="font-bold">Read-only user perspective</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    This never creates a user token and never allows actions. Opening it is audited
                    with your reason.
                  </p>
                </div>
              </div>
              <Button className="mt-4" variant="outline" onClick={loadReadOnlyView}>
                View as user
              </Button>
            </AdminCard>
            {view ? (
              <div className="mt-4">
                <div className="rounded-[12px] border border-warning/30 bg-warning-subtle px-4 py-3 text-sm font-bold">
                  Viewing as {view.user.email} (read-only)
                </div>
                <div className="mt-4 grid gap-4 sm:grid-cols-3">
                  <AdminMetricCard label="Plan" value={view.entitlement.plan.toUpperCase()} />
                  <AdminMetricCard label="Cloud minutes" value={view.balance.available} />
                  <AdminMetricCard label="Channels" value={view.watches.length} />
                </div>
                <p className="mt-4 text-sm text-muted-foreground">
                  Recording metadata is visible. Playback and download are not exposed by this D1
                  view.
                </p>
              </div>
            ) : null}
          </TabsContent>
        </Tabs>

        {error ? <p className="mt-4 text-sm text-destructive">{error}</p> : null}

        <ReasonDialog request={reasonRequest} onClose={() => setReasonRequest(null)} />
        <StepUpDialog
          action={danger}
          user={user}
          open={danger !== null}
          onOpenChange={(open) => !open && setDanger(null)}
          onDone={() => void load()}
        />
        <AccountStatusDialog
          status={statusChange}
          user={user}
          onClose={() => setStatusChange(null)}
          onDone={() => void load()}
        />
      </AppShell>
    </AdminMfaGate>
  );
}
