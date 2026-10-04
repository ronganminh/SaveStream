import { useEffect, useState } from "react";
import { Download, RefreshCw, ShieldAlert } from "lucide-react";
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
  adminFinanceApi,
  adminFoundationApi,
  type AdminLedgerCategory,
  type AdminLedgerEntry,
  type AdminLedgerFilters,
  type AdminPaymentDetail,
  type AdminPaymentFilters,
  type AdminPaymentOrder,
  type AdminRefundPreview,
  type AdminStuckPayment,
  type AdminStuckReservation,
} from "@/repositories/admin-api";

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString("en-US") : "—";
}

function usd(minor: number | null | undefined) {
  return minor === null || minor === undefined ? "—" : `$${(minor / 100).toFixed(2)}`;
}

function minutes(value: number) {
  const hours = Math.floor(Math.abs(value) / 60);
  const mins = Math.abs(value) % 60;
  const sign = value < 0 ? "−" : "";
  return hours ? `${sign}${hours}h ${mins}m` : `${sign}${mins}m`;
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

function StepUpDialog({ action, onClose }: { action: DangerousAction | null; onClose: () => void }) {
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
          <DialogTitle>{action?.title ?? "Confirm finance action"}</DialogTitle>
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

export function AdminFinancePage() {
  const { user } = useAuth();
  const canManageMoney =
    user?.role === "owner" || user?.role === "admin" || user?.role === "finance";

  const [payments, setPayments] = useState<AdminPaymentOrder[]>([]);
  const [paymentFilters, setPaymentFilters] = useState<AdminPaymentFilters>({
    sortOrder: "desc",
  });
  const [paymentCursor, setPaymentCursor] = useState<string | null>(null);
  const [paymentHasMore, setPaymentHasMore] = useState(false);
  const [detail, setDetail] = useState<AdminPaymentDetail | null>(null);
  const [refundAmount, setRefundAmount] = useState("");
  const [refundPreview, setRefundPreview] = useState<AdminRefundPreview | null>(null);

  const [stuck, setStuck] = useState<AdminStuckPayment[]>([]);
  const [ledger, setLedger] = useState<AdminLedgerEntry[]>([]);
  const [ledgerFilters, setLedgerFilters] = useState<AdminLedgerFilters>({ sortOrder: "desc" });
  const [ledgerCursor, setLedgerCursor] = useState<string | null>(null);
  const [ledgerHasMore, setLedgerHasMore] = useState(false);
  const [reservations, setReservations] = useState<AdminStuckReservation[]>([]);

  const [adjustUserId, setAdjustUserId] = useState("");
  const [adjustMinutes, setAdjustMinutes] = useState("");
  const [adjustReason, setAdjustReason] = useState("");
  const [countsAsPurchase, setCountsAsPurchase] = useState(false);
  const [danger, setDanger] = useState<DangerousAction | null>(null);
  const [busy, setBusy] = useState(true);

  const loadPayments = async (cursor?: string | null) => {
    const result = await adminFinanceApi.listPayments({ ...paymentFilters, cursor: cursor ?? null });
    setPayments(result.items);
    setPaymentCursor(result.pagination.next_cursor);
    setPaymentHasMore(result.pagination.has_more);
  };

  const loadFinance = async () => {
    setBusy(true);
    try {
      await loadPayments();
      const stuckResult = await adminFinanceApi.stuckPayments();
      setStuck(stuckResult.items);
      if (canManageMoney) {
        const [ledgerResult, reservationResult] = await Promise.all([
          adminFinanceApi.listLedger(ledgerFilters),
          adminFinanceApi.stuckReservations(),
        ]);
        setLedger(ledgerResult.items);
        setLedgerCursor(ledgerResult.pagination.next_cursor);
        setLedgerHasMore(ledgerResult.pagination.has_more);
        setReservations(reservationResult.items);
      }
    } catch (error) {
      toast.error("Could not load finance operations", { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void loadFinance();
    // Filters are applied explicitly from the page controls.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canManageMoney]);

  const openDetail = async (orderId: string) => {
    try {
      const result = await adminFinanceApi.paymentDetail(orderId);
      setDetail(result);
      setRefundAmount(
        result.order.refund_mode === "admin_web"
          ? String(Math.max(result.order.amount_minor - result.order.refunded_amount_minor, 0))
          : "",
      );
      setRefundPreview(null);
    } catch (error) {
      toast.error("Could not load order", { description: authErrorMessage(error) });
    }
  };

  const previewRefund = async () => {
    if (!detail) return;
    const amountMinor = Number(refundAmount);
    if (!Number.isInteger(amountMinor) || amountMinor <= 0) return;
    try {
      setRefundPreview(await adminFinanceApi.refundPreview(detail.order.id, amountMinor));
    } catch (error) {
      toast.error("Refund preview failed", { description: authErrorMessage(error) });
    }
  };

  const exportPayments = async () => {
    try {
      downloadText("savestream-admin-payments.csv", await adminFinanceApi.exportPayments(paymentFilters));
    } catch (error) {
      toast.error("Payment export failed", { description: authErrorMessage(error) });
    }
  };

  const exportLedger = async () => {
    try {
      downloadText("savestream-admin-credit-ledger.csv", await adminFinanceApi.exportLedger(ledgerFilters));
    } catch (error) {
      toast.error("Ledger export failed", { description: authErrorMessage(error) });
    }
  };

  const refreshAfterMoneyChange = async () => {
    await loadFinance();
    if (detail) setDetail(await adminFinanceApi.paymentDetail(detail.order.id));
  };

  const applyPaymentFilters = () => {
    void loadPayments(null).catch((error) =>
      toast.error("Payment filters failed", { description: authErrorMessage(error) }),
    );
  };

  const applyLedgerFilters = async () => {
    try {
      const result = await adminFinanceApi.listLedger({ ...ledgerFilters, cursor: null });
      setLedger(result.items);
      setLedgerCursor(result.pagination.next_cursor);
      setLedgerHasMore(result.pagination.has_more);
    } catch (error) {
      toast.error("Ledger filters failed", { description: authErrorMessage(error) });
    }
  };

  return (
    <AdminMfaGate>
      <AppShell>
        <PageHeader
          title="Payments & cloud minutes"
          subtitle="Orders, refunds, cloud-minute ledger, reconciliation, and stuck holds."
          action={
            <Button variant="outline" onClick={() => void loadFinance()}>
              <RefreshCw className="mr-2 size-4" />
              Refresh
            </Button>
          }
        />

        {!canManageMoney && (
          <section className="mb-5 rounded-lg border bg-background p-4">
            <p className="text-sm font-medium">Support access is read-only.</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Support can inspect orders for customer support, but cannot refund, reconcile, export
              finance data, change cloud minutes, or release credit holds.
            </p>
          </section>
        )}

        <Tabs defaultValue="orders" className="space-y-5">
          <TabsList>
            <TabsTrigger value="orders">Orders</TabsTrigger>
            <TabsTrigger value="stuck">Stuck orders</TabsTrigger>
            {canManageMoney && <TabsTrigger value="ledger">Credit ledger</TabsTrigger>}
            {canManageMoney && <TabsTrigger value="adjust">Manual minutes</TabsTrigger>}
            {canManageMoney && <TabsTrigger value="holds">Stuck holds</TabsTrigger>}
          </TabsList>

          <TabsContent value="orders" className="space-y-4">
            <div className="grid gap-3 rounded-lg border bg-background p-4 md:grid-cols-4">
              <Input
                placeholder="Email, package, transaction ID"
                value={paymentFilters.query ?? ""}
                onChange={(event) =>
                  setPaymentFilters((current) => ({ ...current, query: event.target.value }))
                }
              />
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={paymentFilters.status ?? ""}
                onChange={(event) =>
                  setPaymentFilters((current) => ({ ...current, status: event.target.value }))
                }
              >
                <option value="">All statuses</option>
                {["created", "pending", "paid", "partially_refunded", "refunded", "failed", "cancelled", "expired"].map((status) => (
                  <option key={status} value={status}>{status}</option>
                ))}
              </select>
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={paymentFilters.channel ?? ""}
                onChange={(event) =>
                  setPaymentFilters((current) => ({
                    ...current,
                    channel: event.target.value as AdminPaymentFilters["channel"],
                  }))
                }
              >
                <option value="">All channels</option>
                <option value="web">Web</option>
                <option value="app_store">App Store</option>
                <option value="google_play">Google Play</option>
              </select>
              <Input
                placeholder="Package ID"
                value={paymentFilters.packageId ?? ""}
                onChange={(event) =>
                  setPaymentFilters((current) => ({ ...current, packageId: event.target.value }))
                }
              />
              <Input
                type="datetime-local"
                value={paymentFilters.createdFrom ?? ""}
                onChange={(event) =>
                  setPaymentFilters((current) => ({ ...current, createdFrom: event.target.value }))
                }
              />
              <Input
                type="datetime-local"
                value={paymentFilters.createdTo ?? ""}
                onChange={(event) =>
                  setPaymentFilters((current) => ({ ...current, createdTo: event.target.value }))
                }
              />
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={paymentFilters.sortOrder ?? "desc"}
                onChange={(event) =>
                  setPaymentFilters((current) => ({
                    ...current,
                    sortOrder: event.target.value as "asc" | "desc",
                  }))
                }
              >
                <option value="desc">Newest first</option>
                <option value="asc">Oldest first</option>
              </select>
              <div className="flex gap-2">
                <Button onClick={applyPaymentFilters}>Apply</Button>
                {canManageMoney && (
                  <Button variant="outline" onClick={() => void exportPayments()}>
                    <Download className="mr-2 size-4" />
                    CSV
                  </Button>
                )}
              </div>
            </div>

            <AdminDataTable>
              <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3">User / package</th>
                  <th className="px-4 py-3">Channel</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Gross USD</th>
                  <th className="px-4 py-3">Estimated store fee</th>
                  <th className="px-4 py-3">Cloud minutes</th>
                  <th className="px-4 py-3">Created</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {payments.map((order) => (
                  <tr key={order.id} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <p className="font-medium">{order.user_email}</p>
                      <p className="text-xs text-muted-foreground">{order.package_name}</p>
                    </td>
                    <td className="px-4 py-3">{order.purchase_channel}</td>
                    <td className="px-4 py-3">{order.status}</td>
                    <td className="px-4 py-3">{usd(order.gross_usd_minor)}</td>
                    <td className="px-4 py-3">
                      {order.estimated_store_fee_minor === null
                        ? "—"
                        : `${usd(order.estimated_store_fee_minor)} (est. ${(order.estimated_store_fee_rate_bps ?? 0) / 100}%)`}
                    </td>
                    <td className="px-4 py-3">{minutes(order.credits)}</td>
                    <td className="px-4 py-3 text-xs">{dateTime(order.created_at)}</td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="outline" onClick={() => void openDetail(order.id)}>
                        Details
                      </Button>
                    </td>
                  </tr>
                ))}
                {!payments.length && (
                  <tr><td colSpan={8} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    {busy ? "Loading orders…" : "No orders match the current filters."}
                  </td></tr>
                )}
              </tbody>
            </AdminDataTable>
            {paymentHasMore && paymentCursor && (
              <Button
                variant="outline"
                onClick={() =>
                  void loadPayments(paymentCursor).catch((error) =>
                    toast.error("Could not load next page", { description: authErrorMessage(error) }),
                  )
                }
              >
                Next page
              </Button>
            )}
          </TabsContent>

          <TabsContent value="stuck" className="space-y-4">
            <section className="rounded-lg border bg-background p-4">
              <h2 className="font-medium">Orders needing attention</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Paid orders missing their idempotent credit grant, or web orders pending for more than 15 minutes.
                Store payment state is never changed manually; only verified Apple or Google events may do that.
              </p>
            </section>
            <AdminDataTable>
              <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3">Order</th>
                  <th className="px-4 py-3">Reason</th>
                  <th className="px-4 py-3">Channel</th>
                  <th className="px-4 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody>
                {stuck.map((item) => (
                  <tr key={item.order.id} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <p className="font-medium">{item.order.user_email}</p>
                      <p className="font-mono text-xs text-muted-foreground">{item.order.id}</p>
                    </td>
                    <td className="px-4 py-3">{item.reason}</td>
                    <td className="px-4 py-3">{item.order.purchase_channel}</td>
                    <td className="px-4 py-3 text-right">
                      {canManageMoney ? (
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={
                            item.reason === "pending_too_long" &&
                            item.order.purchase_channel !== "web"
                          }
                          onClick={() =>
                            setDanger({
                              title: "Reconcile payment order",
                              reason: "Investigate stuck payment order",
                              execute: async (token, reason) => {
                                const result = await adminFinanceApi.reconcilePayment(
                                  item.order.id,
                                  reason,
                                  token,
                                );
                                toast.success(`Reconcile result: ${result.action}`);
                                await loadFinance();
                              },
                            })
                          }
                        >
                          Reconcile
                        </Button>
                      ) : (
                        <span className="text-xs text-muted-foreground">Read-only</span>
                      )}
                    </td>
                  </tr>
                ))}
                {!stuck.length && (
                  <tr><td colSpan={4} className="px-4 py-8 text-center text-sm text-muted-foreground">
                    No stuck orders detected.
                  </td></tr>
                )}
              </tbody>
            </AdminDataTable>
          </TabsContent>

          {canManageMoney && (
            <TabsContent value="ledger" className="space-y-4">
              <div className="grid gap-3 rounded-lg border bg-background p-4 md:grid-cols-5">
                <Input
                  placeholder="User ID"
                  value={ledgerFilters.userId ?? ""}
                  onChange={(event) =>
                    setLedgerFilters((current) => ({ ...current, userId: event.target.value }))
                  }
                />
                <select
                  className="h-9 rounded-md border bg-background px-3 text-sm"
                  value={ledgerFilters.category ?? ""}
                  onChange={(event) =>
                    setLedgerFilters((current) => ({
                      ...current,
                      category: event.target.value as "" | AdminLedgerCategory,
                    }))
                  }
                >
                  <option value="">All categories</option>
                  {["purchase", "spend", "refund", "adjustment", "gift"].map((category) => (
                    <option key={category} value={category}>{category}</option>
                  ))}
                </select>
                <Input
                  type="datetime-local"
                  value={ledgerFilters.createdFrom ?? ""}
                  onChange={(event) =>
                    setLedgerFilters((current) => ({ ...current, createdFrom: event.target.value }))
                  }
                />
                <Input
                  type="datetime-local"
                  value={ledgerFilters.createdTo ?? ""}
                  onChange={(event) =>
                    setLedgerFilters((current) => ({ ...current, createdTo: event.target.value }))
                  }
                />
                <div className="flex gap-2">
                  <Button onClick={() => void applyLedgerFilters()}>Apply</Button>
                  <Button variant="outline" onClick={() => void exportLedger()}>
                    <Download className="mr-2 size-4" />CSV
                  </Button>
                </div>
              </div>
              <AdminDataTable>
                <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                  <tr>
                    <th className="px-4 py-3">User</th>
                    <th className="px-4 py-3">Category</th>
                    <th className="px-4 py-3">Minutes</th>
                    <th className="px-4 py-3">Balance</th>
                    <th className="px-4 py-3">Reference</th>
                    <th className="px-4 py-3">Counts as purchase</th>
                    <th className="px-4 py-3">Created</th>
                  </tr>
                </thead>
                <tbody>
                  {ledger.map((entry) => (
                    <tr key={entry.id} className="border-b last:border-0">
                      <td className="px-4 py-3">{entry.user_email}</td>
                      <td className="px-4 py-3">{entry.category}</td>
                      <td className="px-4 py-3">{minutes(entry.amount)}</td>
                      <td className="px-4 py-3">{minutes(entry.balance_after)}</td>
                      <td className="px-4 py-3 text-xs">{entry.reference_type}</td>
                      <td className="px-4 py-3">{entry.counts_as_purchase ? "Yes" : "No"}</td>
                      <td className="px-4 py-3 text-xs">{dateTime(entry.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </AdminDataTable>
              {ledgerHasMore && ledgerCursor && (
                <Button
                  variant="outline"
                  onClick={() =>
                    void adminFinanceApi
                      .listLedger({ ...ledgerFilters, cursor: ledgerCursor })
                      .then((result) => {
                        setLedger(result.items);
                        setLedgerCursor(result.pagination.next_cursor);
                        setLedgerHasMore(result.pagination.has_more);
                      })
                  }
                >
                  Next page
                </Button>
              )}
            </TabsContent>
          )}

          {canManageMoney && (
            <TabsContent value="adjust">
              <section className="max-w-2xl space-y-4 rounded-lg border bg-background p-5">
                <div>
                  <h2 className="font-medium">Manual cloud-minute adjustment</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Enter minutes directly. Negative values subtract minutes but can never make the balance negative.
                    Gifts do not create Pro entitlement unless “Counts as purchase” is explicitly checked.
                  </p>
                </div>
                <Input
                  placeholder="User ID"
                  value={adjustUserId}
                  onChange={(event) => setAdjustUserId(event.target.value)}
                />
                <Input
                  type="number"
                  placeholder="Minutes, e.g. 120 or -60"
                  value={adjustMinutes}
                  onChange={(event) => {
                    setAdjustMinutes(event.target.value);
                    if (Number(event.target.value) <= 0) setCountsAsPurchase(false);
                  }}
                />
                <Input
                  placeholder="Reason"
                  value={adjustReason}
                  onChange={(event) => setAdjustReason(event.target.value)}
                />
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={countsAsPurchase}
                    disabled={Number(adjustMinutes) <= 0}
                    onChange={(event) => setCountsAsPurchase(event.target.checked)}
                  />
                  Counts as purchase
                </label>
                <Button
                  disabled={
                    !adjustUserId ||
                    !Number.isInteger(Number(adjustMinutes)) ||
                    Number(adjustMinutes) === 0 ||
                    adjustReason.trim().length < 3
                  }
                  onClick={() =>
                    setDanger({
                      title: "Adjust cloud minutes",
                      reason: adjustReason,
                      execute: async (token, reason) => {
                        await adminFinanceApi.adjustCredits(
                          adjustUserId,
                          Number(adjustMinutes),
                          reason,
                          countsAsPurchase,
                          token,
                        );
                        toast.success("Cloud minutes adjusted");
                        setAdjustMinutes("");
                        setAdjustReason("");
                        setCountsAsPurchase(false);
                        await loadFinance();
                      },
                    })
                  }
                >
                  Adjust minutes
                </Button>
              </section>
            </TabsContent>
          )}

          {canManageMoney && (
            <TabsContent value="holds" className="space-y-4">
              <section className="rounded-lg border bg-background p-4">
                <h2 className="font-medium">Stuck credit holds</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Only active reservations whose recording is already terminal are shown. Release re-checks the
                  recording state on the backend before changing the reservation.
                </p>
              </section>
              <AdminDataTable>
                <thead className="border-b bg-muted/40 text-xs uppercase text-muted-foreground">
                  <tr>
                    <th className="px-4 py-3">Recording</th>
                    <th className="px-4 py-3">Status</th>
                    <th className="px-4 py-3">Held</th>
                    <th className="px-4 py-3">Created</th>
                    <th className="px-4 py-3 text-right">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {reservations.map((reservation) => (
                    <tr key={reservation.id} className="border-b last:border-0">
                      <td className="px-4 py-3 font-mono text-xs">{reservation.recording_id}</td>
                      <td className="px-4 py-3">{reservation.recording_status}</td>
                      <td className="px-4 py-3">{minutes(reservation.remaining_reserved)}</td>
                      <td className="px-4 py-3 text-xs">{dateTime(reservation.created_at)}</td>
                      <td className="px-4 py-3 text-right">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            setDanger({
                              title: "Release stuck credit hold",
                              reason: "Release hold after recording ended",
                              execute: async (token, reason) => {
                                const result = await adminFinanceApi.releaseReservation(
                                  reservation.id,
                                  reason,
                                  token,
                                );
                                toast.success(
                                  `Released ${result.released_credits} cloud minutes`,
                                );
                                await loadFinance();
                              },
                            })
                          }
                        >
                          Release
                        </Button>
                      </td>
                    </tr>
                  ))}
                  {!reservations.length && (
                    <tr><td colSpan={5} className="px-4 py-8 text-center text-sm text-muted-foreground">
                      No stuck credit holds.
                    </td></tr>
                  )}
                </tbody>
              </AdminDataTable>
            </TabsContent>
          )}
        </Tabs>

        <Dialog open={detail !== null} onOpenChange={(open) => !open && setDetail(null)}>
          <DialogContent className="max-w-3xl">
            <DialogHeader>
              <DialogTitle>Payment order</DialogTitle>
              <DialogDescription>
                Provider transaction IDs are operational references, not store receipts or secrets.
              </DialogDescription>
            </DialogHeader>
            {detail && (
              <div className="space-y-5">
                <div className="grid gap-3 md:grid-cols-3">
                  <AdminMetricCard label="Gross revenue" value={usd(detail.order.gross_usd_minor)} />
                  <AdminMetricCard label="Cloud minutes" value={minutes(detail.order.credits)} />
                  <AdminMetricCard label="Status" value={detail.order.status} />
                </div>
                <div className="rounded-lg border p-4 text-sm">
                  <p><strong>User:</strong> {detail.order.user_email}</p>
                  <p><strong>Package:</strong> {detail.order.package_name}</p>
                  <p><strong>Channel:</strong> {detail.order.purchase_channel}</p>
                  <p><strong>Transaction:</strong> {detail.order.provider_transaction_id ?? "—"}</p>
                  {detail.order.estimated_store_fee_minor !== null && (
                    <p>
                      <strong>Estimated store fee:</strong>{" "}
                      {usd(detail.order.estimated_store_fee_minor)} at{" "}
                      {(detail.order.estimated_store_fee_rate_bps ?? 0) / 100}%.
                      This is an estimate; revenue above is gross before store fees.
                    </p>
                  )}
                </div>
                {detail.order.refund_mode === "store_managed" ? (
                  <div className="rounded-lg border p-4">
                    <div className="flex items-start gap-3">
                      <ShieldAlert className="mt-0.5 size-5" />
                      <div>
                        <p className="font-medium">Refund managed by Apple or Google</p>
                        <p className="mt-1 text-sm text-muted-foreground">
                          Admin cannot initiate a store refund. SaveStream updates this order only after a verified
                          App Store or Google Play refund notification arrives.
                        </p>
                      </div>
                    </div>
                  </div>
                ) : canManageMoney ? (
                  <div className="space-y-3 rounded-lg border p-4">
                    <h3 className="font-medium">Web refund</h3>
                    <p className="text-sm text-muted-foreground">
                      Amount is in USD cents. Preview calculates the proportional cloud minutes and caps the
                      actual clawback so the user balance never becomes negative.
                    </p>
                    <div className="flex gap-2">
                      <Input
                        type="number"
                        min={1}
                        value={refundAmount}
                        onChange={(event) => {
                          setRefundAmount(event.target.value);
                          setRefundPreview(null);
                        }}
                      />
                      <Button variant="outline" onClick={() => void previewRefund()}>
                        Preview
                      </Button>
                    </div>
                    {refundPreview && (
                      <div className="text-sm">
                        <p>Refund: {usd(refundPreview.amount_minor)}</p>
                        <p>Corresponding minutes: {minutes(refundPreview.corresponding_credits)}</p>
                        <p>Minutes actually deducted now: {minutes(refundPreview.deducted_credits)}</p>
                        {refundPreview.deducted_credits < refundPreview.corresponding_credits && (
                          <p className="mt-1 text-muted-foreground">
                            The remaining refunded minutes were already used; balance stays at or above zero.
                          </p>
                        )}
                        <Button
                          className="mt-3"
                          variant="destructive"
                          onClick={() =>
                            setDanger({
                              title: "Refund web order",
                              reason: "Customer refund",
                              execute: async (token, reason) => {
                                await adminFinanceApi.refund(
                                  detail.order.id,
                                  refundPreview.amount_minor,
                                  refundPreview.corresponding_credits,
                                  reason,
                                  token,
                                );
                                toast.success("Refund requested");
                                setRefundPreview(null);
                                await refreshAfterMoneyChange();
                              },
                            })
                          }
                        >
                          Refund {usd(refundPreview.amount_minor)}
                        </Button>
                      </div>
                    )}
                  </div>
                ) : null}

                <div>
                  <h3 className="mb-2 font-medium">Timeline</h3>
                  <div className="space-y-2">
                    {detail.timeline.map((item, index) => (
                      <div key={`${item.at}-${item.event}-${index}`} className="rounded border p-3 text-sm">
                        <div className="flex justify-between gap-4">
                          <span className="font-mono">{item.event}</span>
                          <span className="text-xs text-muted-foreground">{dateTime(item.at)}</span>
                        </div>
                        {item.detail && <p className="mt-1 text-xs text-muted-foreground">{item.detail}</p>}
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </DialogContent>
        </Dialog>

        <StepUpDialog action={danger} onClose={() => setDanger(null)} />
      </AppShell>
    </AdminMfaGate>
  );
}
