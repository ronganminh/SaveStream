import { useEffect, useMemo, useState } from "react";
import { RefreshCw, ShieldAlert } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, PageHeader } from "@/components/app-components";
import { AdminDataTable, AdminMfaGate, AdminMetricCard } from "@/components/admin/foundation";
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
  adminCatalogApi,
  adminFoundationApi,
  type AdminBulkGrant,
  type AdminBulkGrantDelivery,
  type AdminBulkGrantFilters,
  type AdminCatalogPackage,
  type AdminPromotion,
  type AdminPromotionRedemption,
} from "@/repositories/admin-api";

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString("en-US") : "—";
}

function minutes(value: number) {
  const hours = Math.floor(value / 60);
  const mins = value % 60;
  return hours ? `${hours}h ${mins}m` : `${mins}m`;
}

function usd(minor: number) {
  return `$${(minor / 100).toFixed(2)}`;
}

type DangerousAction = {
  title: string;
  reason: string;
  execute: (token: string, reason: string) => Promise<void>;
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
          <DialogTitle>{action?.title ?? "Confirm catalog action"}</DialogTitle>
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

type PackageDraft = {
  name: string;
  credits: string;
  amountMinor: string;
  displayOrder: string;
  active: boolean;
  appStoreProductId: string;
  googlePlayProductId: string;
  webVariantId: string;
};

function draftFromPackage(item: AdminCatalogPackage): PackageDraft {
  return {
    name: item.name,
    credits: String(item.credits),
    amountMinor: String(item.amount_minor),
    displayOrder: String(item.display_order),
    active: item.active,
    appStoreProductId: item.app_store_product_id ?? "",
    googlePlayProductId: item.google_play_product_id ?? "",
    webVariantId: item.web_variant_id ?? "",
  };
}

export function AdminCatalogPage() {
  const { user } = useAuth();
  const canManage =
    user?.role === "owner" || user?.role === "admin" || user?.role === "finance";

  const [packages, setPackages] = useState<AdminCatalogPackage[]>([]);
  const [selectedPackage, setSelectedPackage] = useState<AdminCatalogPackage | null>(null);
  const [packageDraft, setPackageDraft] = useState<PackageDraft | null>(null);
  const [newPackage, setNewPackage] = useState({
    code: "",
    name: "",
    credits: "",
    amountMinor: "",
    displayOrder: "0",
    appStoreProductId: "",
    googlePlayProductId: "",
    webVariantId: "",
  });

  const [promotions, setPromotions] = useState<AdminPromotion[]>([]);
  const [selectedPromotion, setSelectedPromotion] = useState<AdminPromotion | null>(null);
  const [promotionRedemptions, setPromotionRedemptions] = useState<AdminPromotionRedemption[]>([]);
  const [newPromotion, setNewPromotion] = useState({
    code: "",
    credits: "",
    expiresAt: "",
    maxRedemptions: "",
    countsAsPurchase: false,
  });

  const [bulkCredits, setBulkCredits] = useState("");
  const [bulkCountsAsPurchase, setBulkCountsAsPurchase] = useState(false);
  const [bulkFilters, setBulkFilters] = useState<AdminBulkGrantFilters>({
    plan: "",
    account_status: "active",
    email_verified: "",
  });
  const [bulkPreview, setBulkPreview] = useState<{
    audience_count: number;
    credits_per_user: number;
    total_credits: number;
  } | null>(null);
  const [bulkJob, setBulkJob] = useState<AdminBulkGrant | null>(null);
  const [bulkDeliveries, setBulkDeliveries] = useState<AdminBulkGrantDelivery[]>([]);
  const [danger, setDanger] = useState<DangerousAction | null>(null);
  const [busy, setBusy] = useState(false);

  const webPriceChanged = useMemo(
    () =>
      Boolean(
        selectedPackage &&
          packageDraft &&
          Number(packageDraft.amountMinor) !== selectedPackage.amount_minor,
      ),
    [packageDraft, selectedPackage],
  );

  const load = async () => {
    if (!canManage) return;
    setBusy(true);
    try {
      const [packageResult, promotionResult] = await Promise.all([
        adminCatalogApi.listPackages(),
        adminCatalogApi.listPromotions(),
      ]);
      setPackages(packageResult.items);
      setPromotions(promotionResult.items);
      if (selectedPackage) {
        const refreshed = packageResult.items.find((item) => item.id === selectedPackage.id) ?? null;
        setSelectedPackage(refreshed);
        setPackageDraft(refreshed ? draftFromPackage(refreshed) : null);
      }
    } catch (error) {
      toast.error("Could not load catalog administration", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
    // Load is intentionally gated by the current admin role.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canManage]);

  const openPackage = (item: AdminCatalogPackage) => {
    setSelectedPackage(item);
    setPackageDraft(draftFromPackage(item));
  };

  const openPromotion = async (item: AdminPromotion) => {
    setSelectedPromotion(item);
    try {
      const result = await adminCatalogApi.promotionRedemptions(item.id);
      setPromotionRedemptions(result.items);
    } catch (error) {
      toast.error("Could not load promotion redemptions", {
        description: authErrorMessage(error),
      });
    }
  };

  const refreshBulkReport = async () => {
    if (!bulkJob) return;
    try {
      const [job, deliveries] = await Promise.all([
        adminCatalogApi.getBulkGrant(bulkJob.id),
        adminCatalogApi.bulkGrantDeliveries(bulkJob.id),
      ]);
      setBulkJob(job);
      setBulkDeliveries(deliveries.items);
    } catch (error) {
      toast.error("Could not refresh bulk grant report", {
        description: authErrorMessage(error),
      });
    }
  };

  if (!canManage) {
    return (
      <AdminMfaGate>
        <AppShell>
          <PageHeader
            title="Catalog & promotions"
            subtitle="Package, promotion, and bulk cloud-minute administration."
          />
          <section className="rounded-lg border bg-background p-5">
            <div className="flex gap-3">
              <ShieldAlert className="mt-0.5 size-5" />
              <div>
                <h2 className="font-medium">Finance access required</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Support cannot change packages, promotions, prices, or cloud-minute grants.
                </p>
              </div>
            </div>
          </section>
        </AppShell>
      </AdminMfaGate>
    );
  }

  return (
    <AdminMfaGate>
      <AppShell>
        <PageHeader
          title="Catalog & promotions"
          subtitle="Packages, store identifiers, promotion codes, and bulk cloud-minute grants."
          action={
            <Button variant="outline" disabled={busy} onClick={() => void load()}>
              <RefreshCw className="mr-2 size-4" />
              Refresh
            </Button>
          }
        />

        <Tabs defaultValue="packages" className="space-y-5">
          <TabsList>
            <TabsTrigger value="packages">Packages</TabsTrigger>
            <TabsTrigger value="promotions">Promotions</TabsTrigger>
            <TabsTrigger value="bulk">Bulk grants</TabsTrigger>
          </TabsList>

          <TabsContent value="packages" className="space-y-5">
            <section className="rounded-lg border bg-background p-5">
              <h2 className="font-medium">Create package</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Web prices are USD. App prices are not edited here; only App Store and Google Play product IDs are stored.
              </p>
              <div className="mt-4 grid gap-3 md:grid-cols-4">
                <Input placeholder="Code" value={newPackage.code} onChange={(event) => setNewPackage((current) => ({ ...current, code: event.target.value }))} />
                <Input placeholder="Name" value={newPackage.name} onChange={(event) => setNewPackage((current) => ({ ...current, name: event.target.value }))} />
                <Input type="number" placeholder="Cloud minutes" value={newPackage.credits} onChange={(event) => setNewPackage((current) => ({ ...current, credits: event.target.value }))} />
                <Input type="number" placeholder="Web price (USD cents)" value={newPackage.amountMinor} onChange={(event) => setNewPackage((current) => ({ ...current, amountMinor: event.target.value }))} />
                <Input type="number" placeholder="Display order" value={newPackage.displayOrder} onChange={(event) => setNewPackage((current) => ({ ...current, displayOrder: event.target.value }))} />
                <Input placeholder="App Store product ID" value={newPackage.appStoreProductId} onChange={(event) => setNewPackage((current) => ({ ...current, appStoreProductId: event.target.value }))} />
                <Input placeholder="Google Play product ID" value={newPackage.googlePlayProductId} onChange={(event) => setNewPackage((current) => ({ ...current, googlePlayProductId: event.target.value }))} />
                <Input placeholder="Web provider variant ID" value={newPackage.webVariantId} onChange={(event) => setNewPackage((current) => ({ ...current, webVariantId: event.target.value }))} />
              </div>
              <Button
                className="mt-4"
                disabled={
                  newPackage.code.trim().length < 2 ||
                  !newPackage.name.trim() ||
                  Number(newPackage.credits) <= 0 ||
                  Number(newPackage.amountMinor) < 0
                }
                onClick={() =>
                  setDanger({
                    title: "Create package",
                    reason: "Create catalog package",
                    execute: async (token, reason) => {
                      await adminCatalogApi.createPackage(
                        {
                          code: newPackage.code,
                          name: newPackage.name,
                          credits: Number(newPackage.credits),
                          amount_minor: Number(newPackage.amountMinor),
                          display_order: Number(newPackage.displayOrder) || 0,
                          app_store_product_id: newPackage.appStoreProductId || null,
                          google_play_product_id: newPackage.googlePlayProductId || null,
                          web_variant_id: newPackage.webVariantId || null,
                        },
                        reason,
                        token,
                      );
                      setNewPackage({
                        code: "",
                        name: "",
                        credits: "",
                        amountMinor: "",
                        displayOrder: "0",
                        appStoreProductId: "",
                        googlePlayProductId: "",
                        webVariantId: "",
                      });
                      toast.success("Package created");
                      await load();
                    },
                  })
                }
              >
                Create package
              </Button>
            </section>

            <AdminDataTable>
              <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3">Package</th>
                  <th className="px-4 py-3">Minutes</th>
                  <th className="px-4 py-3">Web price</th>
                  <th className="px-4 py-3">Orders</th>
                  <th className="px-4 py-3">Sale</th>
                  <th className="px-4 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody>
                {packages.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3"><p className="font-medium">{item.name}</p><p className="text-xs text-muted-foreground">{item.code}</p></td>
                    <td className="px-4 py-3">{minutes(item.credits)}</td>
                    <td className="px-4 py-3">{usd(item.amount_minor)}</td>
                    <td className="px-4 py-3">{item.order_count}</td>
                    <td className="px-4 py-3">{item.active ? "Active" : "Hidden"}</td>
                    <td className="px-4 py-3 text-right"><Button size="sm" variant="outline" onClick={() => openPackage(item)}>Edit</Button></td>
                  </tr>
                ))}
              </tbody>
            </AdminDataTable>

            {selectedPackage && packageDraft && (
              <section className="space-y-4 rounded-lg border bg-background p-5">
                <div>
                  <h2 className="font-medium">Edit {selectedPackage.name}</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Packages with orders are never deleted; turn off sale to hide them.
                  </p>
                </div>
                <div className="grid gap-3 md:grid-cols-3">
                  <Input value={packageDraft.name} onChange={(event) => setPackageDraft((current) => current ? { ...current, name: event.target.value } : current)} />
                  <Input type="number" value={packageDraft.credits} onChange={(event) => setPackageDraft((current) => current ? { ...current, credits: event.target.value } : current)} />
                  <Input type="number" value={packageDraft.amountMinor} onChange={(event) => setPackageDraft((current) => current ? { ...current, amountMinor: event.target.value } : current)} />
                  <Input type="number" value={packageDraft.displayOrder} onChange={(event) => setPackageDraft((current) => current ? { ...current, displayOrder: event.target.value } : current)} />
                  <Input placeholder="App Store product ID" value={packageDraft.appStoreProductId} onChange={(event) => setPackageDraft((current) => current ? { ...current, appStoreProductId: event.target.value } : current)} />
                  <Input placeholder="Google Play product ID" value={packageDraft.googlePlayProductId} onChange={(event) => setPackageDraft((current) => current ? { ...current, googlePlayProductId: event.target.value } : current)} />
                  <Input placeholder="Web provider variant ID" value={packageDraft.webVariantId} onChange={(event) => setPackageDraft((current) => current ? { ...current, webVariantId: event.target.value } : current)} />
                  <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={packageDraft.active} onChange={(event) => setPackageDraft((current) => current ? { ...current, active: event.target.checked } : current)} />Available for sale</label>
                </div>
                {webPriceChanged && (
                  <p className="rounded border p-3 text-sm font-medium">
                    Update the price in App Store Connect and Google Play Console as well
                  </p>
                )}
                <p className="text-sm text-muted-foreground">
                  App prices are not edited here. SaveStream only stores the store product IDs and the web payment variant ID.
                </p>
                <Button
                  onClick={() =>
                    setDanger({
                      title: "Update package",
                      reason: "Update catalog package",
                      execute: async (token, reason) => {
                        await adminCatalogApi.updatePackage(
                          selectedPackage.id,
                          {
                            name: packageDraft.name,
                            credits: Number(packageDraft.credits),
                            amount_minor: Number(packageDraft.amountMinor),
                            display_order: Number(packageDraft.displayOrder) || 0,
                            active: packageDraft.active,
                            app_store_product_id: packageDraft.appStoreProductId || null,
                            google_play_product_id: packageDraft.googlePlayProductId || null,
                            web_variant_id: packageDraft.webVariantId || null,
                            clear_app_store_product_id: !packageDraft.appStoreProductId,
                            clear_google_play_product_id: !packageDraft.googlePlayProductId,
                            clear_web_variant_id: !packageDraft.webVariantId,
                          },
                          reason,
                          token,
                        );
                        toast.success("Package updated");
                        await load();
                      },
                    })
                  }
                >
                  Save package
                </Button>
              </section>
            )}
          </TabsContent>

          <TabsContent value="promotions" className="space-y-5">
            <section className="rounded-lg border bg-background p-5">
              <h2 className="font-medium">Create promotion code</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Every code is one redemption per account. Gifts remain Free unless Counts as purchase is explicitly enabled.
              </p>
              <div className="mt-4 grid gap-3 md:grid-cols-4">
                <Input placeholder="Code" value={newPromotion.code} onChange={(event) => setNewPromotion((current) => ({ ...current, code: event.target.value.toUpperCase() }))} />
                <Input type="number" placeholder="Cloud minutes" value={newPromotion.credits} onChange={(event) => setNewPromotion((current) => ({ ...current, credits: event.target.value }))} />
                <Input type="datetime-local" value={newPromotion.expiresAt} onChange={(event) => setNewPromotion((current) => ({ ...current, expiresAt: event.target.value }))} />
                <Input type="number" placeholder="Max redemptions" value={newPromotion.maxRedemptions} onChange={(event) => setNewPromotion((current) => ({ ...current, maxRedemptions: event.target.value }))} />
              </div>
              <label className="mt-3 flex items-center gap-2 text-sm">
                <input type="checkbox" checked={newPromotion.countsAsPurchase} onChange={(event) => setNewPromotion((current) => ({ ...current, countsAsPurchase: event.target.checked }))} />
                Counts as purchase
              </label>
              <Button
                className="mt-4"
                disabled={newPromotion.code.length < 3 || Number(newPromotion.credits) <= 0}
                onClick={() =>
                  setDanger({
                    title: "Create promotion",
                    reason: "Create promotion code",
                    execute: async (token, reason) => {
                      await adminCatalogApi.createPromotion(
                        {
                          code: newPromotion.code,
                          credits: Number(newPromotion.credits),
                          expires_at: newPromotion.expiresAt ? new Date(newPromotion.expiresAt).toISOString() : null,
                          max_redemptions: newPromotion.maxRedemptions ? Number(newPromotion.maxRedemptions) : null,
                          counts_as_purchase: newPromotion.countsAsPurchase,
                        },
                        reason,
                        token,
                      );
                      setNewPromotion({ code: "", credits: "", expiresAt: "", maxRedemptions: "", countsAsPurchase: false });
                      toast.success("Promotion created");
                      await load();
                    },
                  })
                }
              >
                Create promotion
              </Button>
            </section>

            <AdminDataTable>
              <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3">Code</th>
                  <th className="px-4 py-3">Minutes</th>
                  <th className="px-4 py-3">Used</th>
                  <th className="px-4 py-3">Expires</th>
                  <th className="px-4 py-3">Purchase flag</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {promotions.map((item) => (
                  <tr key={item.id} className="border-b last:border-0">
                    <td className="px-4 py-3 font-mono">{item.code}</td>
                    <td className="px-4 py-3">{minutes(item.credits)}</td>
                    <td className="px-4 py-3">{item.redemption_count}{item.max_redemptions ? ` / ${item.max_redemptions}` : ""}</td>
                    <td className="px-4 py-3 text-xs">{dateTime(item.expires_at)}</td>
                    <td className="px-4 py-3">{item.counts_as_purchase ? "Yes" : "No"}</td>
                    <td className="px-4 py-3">{item.active ? "Active" : "Disabled"}</td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="outline" onClick={() => void openPromotion(item)}>Usage</Button>
                      <Button
                        className="ml-2"
                        size="sm"
                        variant="outline"
                        onClick={() =>
                          setDanger({
                            title: item.active ? "Disable promotion" : "Enable promotion",
                            reason: item.active ? "Disable promotion code" : "Enable promotion code",
                            execute: async (token, reason) => {
                              await adminCatalogApi.updatePromotion(item.id, { active: !item.active }, reason, token);
                              toast.success("Promotion updated");
                              await load();
                            },
                          })
                        }
                      >
                        {item.active ? "Disable" : "Enable"}
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </AdminDataTable>

            {selectedPromotion && (
              <section className="rounded-lg border bg-background p-5">
                <h2 className="font-medium">Redemptions — {selectedPromotion.code}</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  One account can redeem this code only once.
                </p>
                <div className="mt-4">
                  <AdminDataTable>
                    <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                      <tr><th className="px-4 py-3">User</th><th className="px-4 py-3">Redeemed</th></tr>
                    </thead>
                    <tbody>
                      {promotionRedemptions.map((item) => (
                        <tr key={item.id} className="border-b last:border-0">
                          <td className="px-4 py-3">{item.user_email}</td>
                          <td className="px-4 py-3 text-xs">{dateTime(item.created_at)}</td>
                        </tr>
                      ))}
                      {!promotionRedemptions.length && (
                        <tr><td colSpan={2} className="px-4 py-8 text-center text-sm text-muted-foreground">No redemptions yet.</td></tr>
                      )}
                    </tbody>
                  </AdminDataTable>
                </div>
              </section>
            )}
          </TabsContent>

          <TabsContent value="bulk" className="space-y-5">
            <section className="rounded-lg border bg-background p-5">
              <h2 className="font-medium">Bulk cloud-minute grant</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Audience uses the D1 customer filters. Preview the user count and total minutes before step-up confirmation.
              </p>
              <div className="mt-4 grid gap-3 md:grid-cols-4">
                <Input type="number" placeholder="Minutes per user" value={bulkCredits} onChange={(event) => { setBulkCredits(event.target.value); setBulkPreview(null); }} />
                <Input placeholder="Email search" value={bulkFilters.query ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, query: event.target.value })); setBulkPreview(null); }} />
                <select className="h-9 rounded-md border bg-background px-3 text-sm" value={bulkFilters.plan ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, plan: event.target.value as "" | "free" | "pro" })); setBulkPreview(null); }}>
                  <option value="">All plans</option><option value="free">Free</option><option value="pro">Pro</option>
                </select>
                <select className="h-9 rounded-md border bg-background px-3 text-sm" value={bulkFilters.account_status ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, account_status: event.target.value as "" | "active" | "locked" | "pending_deletion" | "deleted" })); setBulkPreview(null); }}>
                  <option value="">All account states</option><option value="active">Active</option><option value="locked">Locked</option><option value="pending_deletion">Pending deletion</option><option value="deleted">Deleted</option>
                </select>
                <select className="h-9 rounded-md border bg-background px-3 text-sm" value={bulkFilters.email_verified ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, email_verified: event.target.value as "" | "true" | "false" })); setBulkPreview(null); }}>
                  <option value="">Any email state</option><option value="true">Verified</option><option value="false">Unverified</option>
                </select>
                <Input type="datetime-local" value={bulkFilters.created_from ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, created_from: event.target.value })); setBulkPreview(null); }} />
                <Input type="datetime-local" value={bulkFilters.created_to ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, created_to: event.target.value })); setBulkPreview(null); }} />
                <Input placeholder="Purchase provider" value={bulkFilters.purchase_provider ?? ""} onChange={(event) => { setBulkFilters((current) => ({ ...current, purchase_provider: event.target.value })); setBulkPreview(null); }} />
              </div>
              <label className="mt-3 flex items-center gap-2 text-sm">
                <input type="checkbox" checked={bulkCountsAsPurchase} onChange={(event) => setBulkCountsAsPurchase(event.target.checked)} />
                Counts as purchase
              </label>
              <div className="mt-4 flex gap-2">
                <Button
                  variant="outline"
                  disabled={Number(bulkCredits) <= 0}
                  onClick={() =>
                    void adminCatalogApi
                      .previewBulkGrant(Number(bulkCredits), bulkFilters)
                      .then(setBulkPreview)
                      .catch((error) => toast.error("Bulk preview failed", { description: authErrorMessage(error) }))
                  }
                >
                  Preview audience
                </Button>
                <Button
                  disabled={!bulkPreview || bulkPreview.audience_count === 0}
                  onClick={() =>
                    setDanger({
                      title: "Send bulk cloud-minute grant",
                      reason: "Bulk cloud-minute grant",
                      execute: async (token, reason) => {
                        const job = await adminCatalogApi.createBulkGrant(
                          Number(bulkCredits),
                          bulkFilters,
                          bulkCountsAsPurchase,
                          reason,
                          token,
                        );
                        setBulkJob(job);
                        setBulkDeliveries([]);
                        toast.success("Bulk grant queued");
                      },
                    })
                  }
                >
                  Queue bulk grant
                </Button>
              </div>
              {bulkPreview && (
                <div className="mt-4 grid gap-3 md:grid-cols-3">
                  <AdminMetricCard label="Recipients" value={String(bulkPreview.audience_count)} />
                  <AdminMetricCard label="Minutes each" value={minutes(bulkPreview.credits_per_user)} />
                  <AdminMetricCard label="Total minutes" value={minutes(bulkPreview.total_credits)} />
                </div>
              )}
            </section>

            {bulkJob && (
              <section className="space-y-4 rounded-lg border bg-background p-5">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h2 className="font-medium">Bulk grant report</h2>
                    <p className="mt-1 text-sm text-muted-foreground">Job {bulkJob.id}</p>
                  </div>
                  <Button variant="outline" onClick={() => void refreshBulkReport()}>
                    <RefreshCw className="mr-2 size-4" />
                    Refresh report
                  </Button>
                </div>
                <div className="grid gap-3 md:grid-cols-4">
                  <AdminMetricCard label="Status" value={bulkJob.status} />
                  <AdminMetricCard label="Audience" value={String(bulkJob.audience_count)} />
                  <AdminMetricCard label="Delivered" value={String(bulkJob.delivered_count)} />
                  <AdminMetricCard label="Failed" value={String(bulkJob.failed_count)} />
                </div>
                {bulkJob.error && <p className="text-sm text-destructive">{bulkJob.error}</p>}
                <AdminDataTable>
                  <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                    <tr><th className="px-4 py-3">User</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Error</th></tr>
                  </thead>
                  <tbody>
                    {bulkDeliveries.map((item) => (
                      <tr key={item.id} className="border-b last:border-0">
                        <td className="px-4 py-3">{item.user_email}</td>
                        <td className="px-4 py-3">{item.status}</td>
                        <td className="px-4 py-3 text-xs">{item.error ?? "—"}</td>
                      </tr>
                    ))}
                    {!bulkDeliveries.length && (
                      <tr><td colSpan={3} className="px-4 py-8 text-center text-sm text-muted-foreground">Refresh after the worker starts to see per-user delivery results.</td></tr>
                    )}
                  </tbody>
                </AdminDataTable>
              </section>
            )}
          </TabsContent>
        </Tabs>

        <StepUpDialog action={danger} onClose={() => setDanger(null)} />
      </AppShell>
    </AdminMfaGate>
  );
}
