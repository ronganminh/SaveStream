import { formatAdminDateTime } from "@/lib/formatters";
import { useEffect, useState } from "react";
import { RefreshCw, RotateCcw, Settings2 } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AdminBadge, AdminDataTable, AdminMetricCard } from "@/components/admin/foundation";
import { AppShell, PageHeader } from "@/components/app-components";
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
  adminFoundationApi,
  adminRuntimeSettingsApi,
  type AdminRuntimeSetting,
  type AdminSystemStatus,
} from "@/repositories/admin-api";

type PendingSettingAction = {
  setting: AdminRuntimeSetting;
  mode: "update" | "reset";
};

function displayValue(value: unknown) {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "Enabled" : "Disabled";
  return String(value);
}

function editValue(setting: AdminRuntimeSetting) {
  if (setting.kind === "datetime") {
    if (!setting.value) return "";
    const date = new Date(String(setting.value));
    return Number.isNaN(date.getTime()) ? "" : date.toISOString().slice(0, 16);
  }
  if (setting.kind === "bool") return setting.value ? "true" : "false";
  return setting.value === null || setting.value === undefined ? "" : String(setting.value);
}

function parseValue(setting: AdminRuntimeSetting, value: string): unknown {
  if (setting.kind === "bool") return value === "true";
  if (setting.kind === "int") return Number(value);
  if (setting.kind === "datetime") {
    return value ? new Date(value).toISOString() : null;
  }
  return value;
}

function SettingActionDialog({
  action,
  onClose,
  onSaved,
}: {
  action: PendingSettingAction | null;
  onClose: () => void;
  onSaved: (setting: AdminRuntimeSetting) => void;
}) {
  const [value, setValue] = useState("");
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!action) return;
    setValue(editValue(action.setting));
    setReason("");
    setPassword("");
    setTotp("");
  }, [action]);

  const submit = async () => {
    if (!action) return;
    setBusy(true);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      const result =
        action.mode === "reset"
          ? await adminRuntimeSettingsApi.reset(action.setting.key, reason.trim(), stepUp.token)
          : await adminRuntimeSettingsApi.update(
              action.setting.key,
              parseValue(action.setting, value),
              reason.trim(),
              stepUp.token,
            );
      onSaved(result);
      toast.success(
        action.mode === "reset" ? "Setting reset to environment default" : "Setting updated",
      );
      onClose();
    } catch (error) {
      toast.error("System setting action failed", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  const valid =
    reason.trim().length >= 3 &&
    password.length > 0 &&
    totp.trim().length === 6 &&
    (action?.mode === "reset" || action?.setting.nullable || value.trim().length > 0);

  return (
    <Dialog open={action !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {action?.mode === "reset" ? "Reset system setting" : "Update system setting"}
          </DialogTitle>
          <DialogDescription>
            {action?.setting.key}. This action requires Owner step-up authentication and is written
            to the permanent admin audit log.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          {action?.mode === "update" && action.setting.kind === "bool" && (
            <select
              className="h-9 w-full rounded-md border bg-background px-3 text-sm"
              value={value}
              onChange={(event) => setValue(event.target.value)}
            >
              <option value="true">Enabled</option>
              <option value="false">Disabled</option>
            </select>
          )}
          {action?.mode === "update" && action.setting.kind === "enum" && (
            <select
              className="h-9 w-full rounded-md border bg-background px-3 text-sm"
              value={value}
              onChange={(event) => setValue(event.target.value)}
            >
              {action.setting.choices.map((choice) => (
                <option value={choice} key={choice}>
                  {choice}
                </option>
              ))}
            </select>
          )}
          {action?.mode === "update" &&
            action.setting.kind !== "bool" &&
            action.setting.kind !== "enum" && (
              <Input
                type={
                  action.setting.kind === "int"
                    ? "number"
                    : action.setting.kind === "datetime"
                      ? "datetime-local"
                      : "text"
                }
                min={action.setting.minimum ?? undefined}
                max={action.setting.maximum ?? undefined}
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder={action.setting.nullable ? "Leave empty for no value" : undefined}
              />
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

// SaveStream is web-only with PayPal checkout for now. These settings only
// affect the (paused) mobile apps and store purchases, so the web admin hides
// them; the backend keeps them so the mobile source can be resumed later.
const MOBILE_ONLY_SETTING_KEYS = new Set([
  "app_min_supported_android",
  "app_min_supported_ios",
  "pro_local_recording",
  "free_local_daily_minutes",
  "reward_daily_cap",
  "reward_minutes",
  "payment_app_store_enabled",
  "payment_google_play_enabled",
]);

export function AdminSystemD4Page() {
  const { identity } = useAuth();
  const isOwner = identity.role === "owner" || identity.role === "admin";
  const [status, setStatus] = useState<AdminSystemStatus | null>(null);
  const [settings, setSettings] = useState<AdminRuntimeSetting[]>([]);
  const [pending, setPending] = useState<PendingSettingAction | null>(null);
  const [busy, setBusy] = useState(true);

  const load = async () => {
    setBusy(true);
    try {
      const [systemStatus, settingsResult] = await Promise.all([
        adminRuntimeSettingsApi.systemStatus(),
        isOwner
          ? adminRuntimeSettingsApi.list()
          : Promise.resolve({ items: [] as AdminRuntimeSetting[] }),
      ]);
      setStatus(systemStatus);
      setSettings(settingsResult.items.filter((item) => !MOBILE_ONLY_SETTING_KEYS.has(item.key)));
    } catch (error) {
      toast.error("Could not load System", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
    // Owner identity is stable for an authenticated admin session.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOwner]);

  const saveSetting = (updated: AdminRuntimeSetting) => {
    setSettings((current) => current.map((item) => (item.key === updated.key ? updated : item)));
  };

  const healthOrder = ["api", "database", "redis", "storage", "smtp"];
  const healthLabels: Record<string, string> = {
    api: "API",
    database: "Database",
    redis: "Redis",
    storage: "R2 / object storage",
    smtp: "SMTP",
  };

  return (
    <AppShell>
      <PageHeader
        title="System"
        subtitle="Runtime product configuration and dependency health. Secret-backed infrastructure settings are never exposed here."
        action={
          <Button variant="outline" disabled={busy} onClick={() => void load()}>
            <RefreshCw className="size-4" />
            {busy ? "Refreshing…" : "Refresh"}
          </Button>
        }
      />

      <div className="grid gap-3 md:grid-cols-2">
        <AdminMetricCard label="Backend version" value={status?.backend_version ?? "—"} />
        <AdminMetricCard label="Started at" value={formatAdminDateTime(status?.started_at)} />
      </div>

      <section className="mt-6" aria-labelledby="system-health">
        <div className="mb-3 flex flex-wrap items-end justify-between gap-2">
          <h2 id="system-health" className="text-[17px] font-bold tracking-[-.01em]">
            Service health
          </h2>
          <p className="text-xs text-muted-foreground">
            Health checks return status only. Credentials, connection strings, and secret values are
            never returned by the Admin API.
          </p>
        </div>
        <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-3">
          {healthOrder.map((key) => {
            const item = status?.components[key];
            const ok = item?.status === "ok";
            return (
              <div key={key} className="flex flex-col gap-2 rounded-[16px] border bg-surface p-4">
                <div className="flex items-center gap-2.5">
                  <span
                    className={`size-2.5 rounded-full ${!item ? "bg-muted-foreground/40" : ok ? "bg-success" : "bg-destructive"}`}
                    aria-hidden="true"
                  />
                  <b className="flex-1 text-sm">{healthLabels[key]}</b>
                  <AdminBadge tone={!item ? "neutral" : ok ? "success" : "danger"}>
                    {ok ? "Healthy" : item ? "Error" : "Loading…"}
                  </AdminBadge>
                </div>
                <p className="min-h-4 text-xs text-muted-foreground">{item?.detail ?? ""}</p>
              </div>
            );
          })}
        </div>
      </section>

      <section className="mt-8 space-y-4">
        <div>
          <h2 className="flex items-center gap-2 text-[17px] font-bold tracking-[-.01em]">
            <Settings2 className="size-4" />
            Runtime product settings
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {isOwner
              ? "Database overrides take effect immediately and fall back to environment defaults when reset."
              : "Only Owner can view and change runtime product settings."}
          </p>
        </div>

        {isOwner && (
          <AdminDataTable>
            <thead>
              <tr className="border-b">
                <th className="px-4 py-3">Setting</th>
                <th className="px-4 py-3">Current</th>
                <th className="px-4 py-3">Default</th>
                <th className="px-4 py-3">Source</th>
                <th className="px-4 py-3">Updated</th>
                <th className="px-4 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {settings.map((setting) => (
                <tr key={setting.key} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    <p className="font-mono text-xs font-bold">{setting.key}</p>
                    <p className="mt-1 max-w-md text-xs text-muted-foreground">
                      {setting.description}
                    </p>
                  </td>
                  <td className="px-4 py-3">
                    <code className="rounded-md bg-surface-2 px-2 py-1 font-mono text-xs">
                      {displayValue(setting.value)}
                    </code>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                    {displayValue(setting.default_value)}
                  </td>
                  <td className="px-4 py-3">
                    <AdminBadge tone={setting.source === "database" ? "accent" : "neutral"}>
                      {setting.source === "database" ? "Override" : setting.source}
                    </AdminBadge>
                  </td>
                  <td className="px-4 py-3 text-xs">{formatAdminDateTime(setting.updated_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => setPending({ setting, mode: "update" })}
                      >
                        Edit
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={setting.source !== "database"}
                        onClick={() => setPending({ setting, mode: "reset" })}
                      >
                        <RotateCcw className="size-3" />
                        Reset
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
              {!settings.length && (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    {busy ? "Loading settings…" : "No runtime settings available."}
                  </td>
                </tr>
              )}
            </tbody>
          </AdminDataTable>
        )}
      </section>

      <SettingActionDialog
        action={pending}
        onClose={() => setPending(null)}
        onSaved={saveSetting}
      />
    </AppShell>
  );
}
