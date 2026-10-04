import { useEffect, useState } from "react";
import { RefreshCw, RotateCcw, Settings2 } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AdminDataTable, AdminMetricCard } from "@/components/admin/foundation";
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
    (action?.mode === "reset" ||
      action?.setting.nullable ||
      value.trim().length > 0);

  return (
    <Dialog open={action !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {action?.mode === "reset" ? "Reset system setting" : "Update system setting"}
          </DialogTitle>
          <DialogDescription>
            {action?.setting.key}. This action requires Owner step-up authentication and is
            written to the permanent admin audit log.
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
      setSettings(settingsResult.items);
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
    setSettings((current) =>
      current.map((item) => (item.key === updated.key ? updated : item)),
    );
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
            <RefreshCw className="mr-2 size-4" />
            {busy ? "Refreshing…" : "Refresh"}
          </Button>
        }
      />

      <div className="grid gap-3 md:grid-cols-2">
        <AdminMetricCard label="Backend version" value={status?.backend_version ?? "—"} />
        <AdminMetricCard
          label="Started at"
          value={status?.started_at ? new Date(status.started_at).toLocaleString("en-US") : "—"}
        />
      </div>

      <section className="mt-6 rounded-lg border bg-background">
        <div className="border-b p-5">
          <h2 className="font-medium">Service health</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Health checks return status only. Credentials, connection strings, and secret values are
            never returned by the Admin API.
          </p>
        </div>
        <div className="grid sm:grid-cols-2">
          {healthOrder.map((key) => {
            const item = status?.components[key];
            return (
              <div
                key={key}
                className="flex items-center justify-between gap-4 border-b p-4 text-sm sm:odd:border-r"
              >
                <span>{healthLabels[key]}</span>
                <span
                  className={
                    item?.status === "ok"
                      ? "font-medium text-foreground"
                      : "font-medium text-destructive"
                  }
                >
                  {item?.status === "ok" ? "Healthy" : item ? "Error" : "Loading…"}
                  {item?.detail ? ` · ${item.detail}` : ""}
                </span>
              </div>
            );
          })}
        </div>
      </section>

      <section className="mt-8 space-y-4">
        <div>
          <h2 className="flex items-center gap-2 font-medium">
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
            <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
              <tr>
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
                    <p className="font-mono text-xs font-medium">{setting.key}</p>
                    <p className="mt-1 max-w-md text-xs text-muted-foreground">
                      {setting.description}
                    </p>
                  </td>
                  <td className="px-4 py-3 text-sm">{displayValue(setting.value)}</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">
                    {displayValue(setting.default_value)}
                  </td>
                  <td className="px-4 py-3 text-sm">{setting.source}</td>
                  <td className="px-4 py-3 text-xs">
                    {setting.updated_at
                      ? new Date(setting.updated_at).toLocaleString("en-US")
                      : "—"}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setPending({ setting, mode: "update" })}
                      >
                        Edit
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={setting.source !== "database"}
                        onClick={() => setPending({ setting, mode: "reset" })}
                      >
                        <RotateCcw className="mr-1 size-3" />
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
