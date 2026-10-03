import { useEffect, useMemo, useState, type ReactNode } from "react";
import { ShieldCheck } from "lucide-react";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
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
import { isAdminRole, isDemoMode } from "@/lib/app-config";
import {
  adminFoundationApi,
  type AdminMfaSetup,
  type AdminRole,
  type AdminUser,
} from "@/repositories/admin-api";

export function AdminMetricCard({
  label,
  value,
  detail,
}: {
  label: string;
  value: ReactNode;
  detail?: ReactNode;
}) {
  return (
    <div className="rounded-lg border bg-background p-4">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
      {detail ? <div className="mt-1 text-xs text-muted-foreground">{detail}</div> : null}
    </div>
  );
}

export function AdminDataTable({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-lg border bg-background">
      <table className="w-full min-w-[720px] text-left text-sm">{children}</table>
    </div>
  );
}

export function AdminTimeline({ items }: { items: readonly string[] }) {
  return (
    <ol className="space-y-3">
      {items.map((item) => (
        <li key={item} className="flex gap-3 text-sm">
          <span className="mt-2 size-1.5 shrink-0 rounded-full bg-primary" />
          <span>{item}</span>
        </li>
      ))}
    </ol>
  );
}

export function AdminGlobalSearch() {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<Awaited<ReturnType<typeof adminFoundationApi.search>>["items"]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const search = async () => {
    const term = query.trim();
    if (term.length < 2) {
      setItems([]);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const result = await adminFoundationApi.search(term);
      setItems(result.items);
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="relative">
      <form
        className="flex gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          void search();
        }}
      >
        <Input
          aria-label="Global admin search"
          placeholder="Search email, user ID, order ID, recording ID, or request ID"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <Button type="submit" variant="outline" disabled={busy || query.trim().length < 2}>
          {busy ? "Searching…" : "Search"}
        </Button>
      </form>
      {error ? <p className="mt-2 text-sm text-destructive">{error}</p> : null}
      {items.length ? (
        <div className="absolute z-30 mt-2 w-full rounded-lg border bg-background p-2 shadow-lg">
          {items.map((item) => (
            <a
              key={`${item.type}:${item.id}`}
              href={item.href}
              className="block rounded-md px-3 py-2 text-sm hover:bg-muted"
            >
              <span className="font-medium">{item.label}</span>
              <span className="ml-2 text-xs uppercase text-muted-foreground">{item.type}</span>
              {item.detail ? (
                <span className="mt-1 block text-xs text-muted-foreground">{item.detail}</span>
              ) : null}
            </a>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function MfaCard({
  enabled,
  setup,
  code,
  busy,
  error,
  onCodeChange,
  onStartSetup,
  onSubmit,
}: {
  enabled: boolean;
  setup: AdminMfaSetup | null;
  code: string;
  busy: boolean;
  error: string | null;
  onCodeChange: (value: string) => void;
  onStartSetup: () => void;
  onSubmit: () => void;
}) {
  return (
    <div className="w-full max-w-xl rounded-xl border bg-background p-6 shadow-sm">
      <div className="flex items-start gap-3">
        <span className="grid size-10 shrink-0 place-items-center rounded-full bg-primary/10 text-primary">
          <ShieldCheck className="size-5" />
        </span>
        <div>
          <h1 className="text-xl font-semibold">
            {enabled ? "Verify two-factor authentication" : "Set up two-factor authentication"}
          </h1>
          <p className="mt-1 text-sm leading-6 text-muted-foreground">
            SaveStream requires an authenticator app for every administrator.
          </p>
        </div>
      </div>

      {!enabled && !setup ? (
        <Button className="mt-6" onClick={onStartSetup} disabled={busy}>
          Start setup
        </Button>
      ) : null}

      {setup ? (
        <div className="mt-6 space-y-5">
          <div className="rounded-lg border bg-white p-4">
            <img
              className="mx-auto size-48"
              alt="Authenticator QR code"
              src={`data:image/svg+xml;charset=utf-8,${encodeURIComponent(setup.qr_svg)}`}
            />
          </div>
          <div>
            <p className="text-sm font-medium">Manual setup key</p>
            <code className="mt-2 block overflow-x-auto rounded-md bg-muted p-3 text-xs">
              {setup.secret}
            </code>
          </div>
          <div>
            <p className="text-sm font-medium">Recovery codes</p>
            <p className="mt-1 text-xs text-muted-foreground">
              Store these codes somewhere safe. Each recovery code works once.
            </p>
            <div className="mt-2 grid grid-cols-2 gap-2 rounded-md bg-muted p-3 font-mono text-xs">
              {setup.recovery_codes.map((recoveryCode) => (
                <span key={recoveryCode}>{recoveryCode}</span>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {(enabled || setup) ? (
        <div className="mt-6">
          <label htmlFor="admin-mfa-code" className="text-sm font-medium">
            Authentication code
          </label>
          <Input
            id="admin-mfa-code"
            className="mt-2 font-mono"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={code}
            onChange={(event) => onCodeChange(event.target.value)}
            placeholder="123456"
            maxLength={64}
          />
          {error ? <p className="mt-2 text-sm text-destructive">{error}</p> : null}
          <Button className="mt-4" onClick={onSubmit} disabled={busy || code.trim().length < 6}>
            {enabled ? "Verify and continue" : "Enable and continue"}
          </Button>
        </div>
      ) : null}
    </div>
  );
}

export function AdminMfaGate({ children }: { children: ReactNode }) {
  const { user, refreshSession } = useAuth();
  const [setup, setSetup] = useState<AdminMfaSetup | null>(null);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!user || !isAdminRole(user.role) || isDemoMode || user.admin_mfa_verified) {
    return <>{children}</>;
  }

  const startSetup = async () => {
    setBusy(true);
    setError(null);
    try {
      setSetup(await adminFoundationApi.beginMfaSetup());
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  const submit = async () => {
    setBusy(true);
    setError(null);
    try {
      if (user.admin_mfa_enabled) {
        await adminFoundationApi.verifyMfa(code.trim());
      } else {
        await adminFoundationApi.enableMfa(code.trim());
      }
      await refreshSession();
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid min-h-screen place-items-center bg-muted/30 p-6">
      <MfaCard
        enabled={user.admin_mfa_enabled}
        setup={setup}
        code={code}
        busy={busy}
        error={error}
        onCodeChange={setCode}
        onStartSetup={() => void startSetup()}
        onSubmit={() => void submit()}
      />
    </div>
  );
}

type StepUpAction =
  | { kind: "role"; admin: AdminUser; role: "user" | AdminRole }
  | { kind: "mfa"; admin: AdminUser };

function AdminStepUpDialog({
  action,
  onClose,
  onDone,
}: {
  action: StepUpAction | null;
  onClose: () => void;
  onDone: (updated: AdminUser) => void;
}) {
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totpCode, setTotpCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setReason("");
    setPassword("");
    setTotpCode("");
    setError(null);
  }, [action]);

  const submit = async () => {
    if (!action) return;
    setBusy(true);
    setError(null);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totpCode);
      const updated =
        action.kind === "role"
          ? await adminFoundationApi.updateAdminRole(
              action.admin.id,
              action.role,
              reason.trim(),
              stepUp.token,
            )
          : await adminFoundationApi.resetAdminMfa(
              action.admin.id,
              reason.trim(),
              stepUp.token,
            );
      onDone(updated);
      onClose();
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={action !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {action?.kind === "role" ? "Confirm admin role change" : "Reset two-factor authentication"}
          </DialogTitle>
          <DialogDescription>
            Re-enter your password, current authenticator code, and the reason for this action.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div>
            <label htmlFor="admin-stepup-reason" className="text-sm font-medium">
              Reason
            </label>
            <Input
              id="admin-stepup-reason"
              className="mt-2"
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              minLength={3}
              maxLength={500}
            />
          </div>
          <div>
            <label htmlFor="admin-stepup-password" className="text-sm font-medium">
              Password
            </label>
            <Input
              id="admin-stepup-password"
              className="mt-2"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </div>
          <div>
            <label htmlFor="admin-stepup-totp" className="text-sm font-medium">
              Authenticator code
            </label>
            <Input
              id="admin-stepup-totp"
              className="mt-2 font-mono"
              inputMode="numeric"
              autoComplete="one-time-code"
              value={totpCode}
              onChange={(event) => setTotpCode(event.target.value)}
              maxLength={6}
            />
          </div>
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button
            onClick={() => void submit()}
            disabled={
              busy || reason.trim().length < 3 || !password || totpCode.trim().length !== 6
            }
          >
            Confirm
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export function AdminOwnerAccessPanel() {
  const { user } = useAuth();
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [draftRoles, setDraftRoles] = useState<Record<string, "user" | AdminRole>>({});
  const [action, setAction] = useState<StepUpAction | null>(null);
  const [error, setError] = useState<string | null>(null);

  const isOwner = user?.role === "owner" || user?.role === "admin";

  useEffect(() => {
    if (!isOwner || isDemoMode) return;
    let cancelled = false;
    void adminFoundationApi
      .listAdmins()
      .then((result) => {
        if (cancelled) return;
        setAdmins(result.items);
        setDraftRoles(
          Object.fromEntries(
            result.items.map((admin) => [
              admin.id,
              admin.role === "admin" ? "owner" : admin.role === "user" ? "user" : admin.role,
            ]),
          ),
        );
      })
      .catch((requestError) => {
        if (!cancelled) setError(authErrorMessage(requestError));
      });
    return () => {
      cancelled = true;
    };
  }, [isOwner]);

  const visibleAdmins = useMemo(
    () => admins.slice().sort((a, b) => a.email.localeCompare(b.email)),
    [admins],
  );

  if (!isOwner) return null;

  if (isDemoMode) {
    return (
      <section className="rounded-lg border bg-background p-5">
        <h2 className="text-base font-semibold">Admin access</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Owner-only role assignment, MFA reset, and step-up confirmation are available in production mode.
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-4 rounded-lg border bg-background p-5">
      <div>
        <h2 className="text-base font-semibold">Admin access</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Only Owners can assign or revoke admin roles and reset another administrator's two-factor authentication.
        </p>
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      <AdminDataTable>
        <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
          <tr>
            <th className="px-4 py-3">Administrator</th>
            <th className="px-4 py-3">Current role</th>
            <th className="px-4 py-3">New role</th>
            <th className="px-4 py-3 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          {visibleAdmins.map((admin) => {
            const currentRole = admin.role === "admin" ? "owner" : admin.role;
            const draftRole = draftRoles[admin.id] ?? currentRole;
            return (
              <tr key={admin.id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <p className="font-medium">{admin.email}</p>
                  <p className="text-xs text-muted-foreground">{admin.display_name ?? admin.id}</p>
                </td>
                <td className="px-4 py-3 capitalize">{currentRole}</td>
                <td className="px-4 py-3">
                  <select
                    className="h-9 rounded-md border bg-background px-2 text-sm"
                    value={draftRole}
                    onChange={(event) =>
                      setDraftRoles((current) => ({
                        ...current,
                        [admin.id]: event.target.value as "user" | AdminRole,
                      }))
                    }
                  >
                    <option value="owner">Owner</option>
                    <option value="support">Support</option>
                    <option value="finance">Finance</option>
                    <option value="user">Revoke admin access</option>
                  </select>
                </td>
                <td className="px-4 py-3">
                  <div className="flex justify-end gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={draftRole === currentRole}
                      onClick={() => setAction({ kind: "role", admin, role: draftRole })}
                    >
                      Change role
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => setAction({ kind: "mfa", admin })}
                    >
                      Reset 2FA
                    </Button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </AdminDataTable>
      <AdminStepUpDialog
        action={action}
        onClose={() => setAction(null)}
        onDone={(updated) => {
          setAdmins((current) => current.map((item) => (item.id === updated.id ? updated : item)));
          setDraftRoles((current) => ({
            ...current,
            [updated.id]:
              updated.role === "admin"
                ? "owner"
                : updated.role === "user"
                  ? "user"
                  : updated.role,
          }));
        }}
      />
    </section>
  );
}
