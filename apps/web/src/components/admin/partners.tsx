import { useEffect, useState, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { ExternalLink, RefreshCw, Search } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { AppShell, AvatarCircle, PageHeader } from "@/components/app-components";
import {
  AdminBadge,
  AdminCard,
  AdminDataTable,
  type AdminBadgeTone,
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
import { Textarea } from "@/components/ui/textarea";
import { formatAdminDateTime } from "@/lib/formatters";
import { cn } from "@/lib/utils";
import { initials } from "@/repositories/mappers/channel";
import {
  adminFoundationApi,
  adminPartnersApi,
  type AdminPartnerAction,
  type AdminPartnerApplication,
  type AdminPartnerStatus,
} from "@/repositories/admin-api";

const MIN_REASON_LENGTH = 10;

/** "Oct 14, 2026" for the list; the detail panel shows the full timestamp. */
function shortDate(value: string) {
  return new Date(value).toLocaleDateString("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

const statusLabel: Record<AdminPartnerStatus, string> = {
  pending: "Pending",
  approved: "Approved",
  published: "Published",
  rejected: "Rejected",
  withdrawn: "Withdrawn",
};

const statusTone: Record<AdminPartnerStatus, AdminBadgeTone> = {
  pending: "warning",
  approved: "info",
  published: "success",
  rejected: "danger",
  withdrawn: "neutral",
};

const filterChips: [AdminPartnerStatus | "", string][] = [
  ["", "All"],
  ["pending", "Pending"],
  ["approved", "Approved"],
  ["published", "Published"],
  ["rejected", "Rejected"],
  ["withdrawn", "Withdrawn"],
];

/** Which actions each status allows; mirrors the backend transitions. */
const actionsFor: Record<AdminPartnerStatus, AdminPartnerAction[]> = {
  pending: ["approve", "reject", "unpublish"],
  approved: ["publish", "reject", "unpublish"],
  published: ["unpublish"],
  rejected: ["approve"],
  withdrawn: [],
};

const actionCopy: Record<
  AdminPartnerAction,
  { label: string; title: string; variant: "default" | "outline" | "destructive" }
> = {
  approve: { label: "Approve", title: "Approve application", variant: "default" },
  reject: { label: "Reject", title: "Reject application", variant: "outline" },
  publish: { label: "Publish story", title: "Publish story", variant: "default" },
  unpublish: {
    label: "Unpublish (consent withdrawn)",
    title: "Unpublish — consent withdrawn",
    variant: "destructive",
  },
};

function StatusBadge({ status }: { status: AdminPartnerStatus }) {
  return (
    <AdminBadge tone={statusTone[status]} dot>
      {statusLabel[status]}
    </AdminBadge>
  );
}

function ActionDialog({
  application,
  action,
  onClose,
  onDone,
}: {
  application: AdminPartnerApplication;
  action: AdminPartnerAction | null;
  onClose: () => void;
  onDone: (updated: AdminPartnerApplication) => void;
}) {
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => setReason(""), [action]);
  if (!action) return null;
  const copy = actionCopy[action];

  const confirm = async () => {
    setBusy(true);
    try {
      const updated = await adminPartnersApi.act(application.id, action, reason.trim());
      toast.success(`${copy.title}: done`);
      onDone(updated);
    } catch (error) {
      toast.error(`${copy.title} failed`, { description: authErrorMessage(error) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open onOpenChange={(open) => (!open ? onClose() : undefined)}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{copy.title}</DialogTitle>
          <DialogDescription>
            {application.name} · @{application.tiktok_handle}. The reason is written to the audit
            log as <code>partner.{action}</code>.
          </DialogDescription>
        </DialogHeader>
        {action === "unpublish" ? (
          <p className="rounded-[12px] bg-warning-subtle px-3 py-2 text-sm text-warning-foreground">
            The story is taken down and consent is recorded as withdrawn. It cannot be published
            again from this application.
          </p>
        ) : null}
        <label className="flex flex-col gap-1.5 text-sm font-bold">
          Reason
          <Textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder={`At least ${MIN_REASON_LENGTH} characters`}
            className="font-normal"
          />
        </label>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={copy.variant === "destructive" ? "destructive" : "default"}
            disabled={busy || reason.trim().length < MIN_REASON_LENGTH}
            onClick={() => void confirm()}
          >
            {busy ? "Saving…" : copy.label}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Photo({ application }: { application: AdminPartnerApplication }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    if (!application.has_photo) return;
    let objectUrl: string | null = null;
    let cancelled = false;
    setUrl(null);
    setFailed(false);
    adminPartnersApi.photoUrl(application.id).then(
      (created) => {
        objectUrl = created;
        if (cancelled) URL.revokeObjectURL(created);
        else setUrl(created);
      },
      () => !cancelled && setFailed(true),
    );
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [application.id, application.has_photo]);

  if (!application.has_photo) {
    return <p className="text-sm text-muted-foreground">No logo or photo attached.</p>;
  }
  if (failed) return <p className="text-sm text-destructive">The photo could not be loaded.</p>;
  return url ? (
    <img
      src={url}
      alt={`Photo from ${application.name}`}
      className="aspect-square w-full max-w-[220px] rounded-[14px] border object-cover"
    />
  ) : (
    <div className="aspect-square w-full max-w-[220px] animate-pulse rounded-[14px] bg-surface-2" />
  );
}

const REWARD_HOURS_DEFAULT = 50;
const CREDITS_PER_HOUR = 60;

function RewardDialog({
  application,
  hours,
  open,
  onClose,
  onDone,
}: {
  application: AdminPartnerApplication;
  hours: number;
  open: boolean;
  onClose: () => void;
  onDone: (updated: AdminPartnerApplication) => void;
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
  }, [open]);

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      const updated = await adminPartnersApi.grantReward(
        application.id,
        hours,
        reason.trim(),
        stepUp.token,
      );
      toast.success(`Granted ${hours} h to ${application.email}`);
      onDone(updated);
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={(next) => (!next && !busy ? onClose() : undefined)}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Grant {hours} recording hours</DialogTitle>
          <DialogDescription>
            {hours * CREDITS_PER_HOUR} credits to {application.email}. Granted once per application;
            written to the credit ledger and the audit log as <code>partner.reward_granted</code>.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <Textarea
            placeholder={`Reason (at least ${MIN_REASON_LENGTH} characters)`}
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
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button
            disabled={
              busy || reason.trim().length < MIN_REASON_LENGTH || !password || totp.length !== 6
            }
            onClick={() => void confirm()}
          >
            {busy ? "Granting…" : `Grant ${hours} h`}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function RewardCard({
  application,
  canGrant,
  onUpdated,
}: {
  application: AdminPartnerApplication;
  canGrant: boolean;
  onUpdated: (updated: AdminPartnerApplication) => void;
}) {
  const [hours, setHours] = useState(REWARD_HOURS_DEFAULT);
  const [open, setOpen] = useState(false);
  useEffect(() => setHours(REWARD_HOURS_DEFAULT), [application.id]);
  const validHours = Number.isInteger(hours) && hours >= 1 && hours <= 500;

  let body: ReactNode;
  if (application.reward_credits) {
    body = (
      <AdminBadge tone="success">
        Granted {Math.round(application.reward_credits / CREDITS_PER_HOUR)} h ·{" "}
        {formatAdminDateTime(application.reward_granted_at)}
      </AdminBadge>
    );
  } else if (application.status !== "published") {
    body = (
      <p className="text-sm text-muted-foreground">
        {REWARD_HOURS_DEFAULT} h are granted once the story is published.
      </p>
    );
  } else if (!application.account_user_id) {
    body = (
      <p className="rounded-[12px] bg-warning-subtle px-3 py-2 text-sm text-warning-foreground">
        No SaveStream account uses {application.email}. Ask the creator to sign up with that email,
        then grant the reward.
      </p>
    );
  } else {
    body = (
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex h-10 items-center rounded-[12px] border bg-surface pr-3">
          <input
            type="number"
            min={1}
            max={500}
            aria-label="Reward hours"
            className="h-full w-20 bg-transparent px-3 font-mono text-sm outline-none"
            value={hours}
            onChange={(event) => setHours(Number(event.target.value))}
          />
          <span className="text-sm text-muted-foreground">h</span>
        </div>
        <Button disabled={!canGrant || !validHours} onClick={() => setOpen(true)}>
          Grant hours
        </Button>
        {!canGrant ? (
          <span className="text-xs text-muted-foreground">
            Needs the credit-adjust permission (Owner).
          </span>
        ) : null}
      </div>
    );
  }

  return (
    <AdminCard
      title="Reward hours"
      description={`Partner welcome reward: ${REWARD_HOURS_DEFAULT} h (${
        REWARD_HOURS_DEFAULT * CREDITS_PER_HOUR
      } credits), once per application.`}
    >
      {body}
      <RewardDialog
        application={application}
        hours={hours}
        open={open}
        onClose={() => setOpen(false)}
        onDone={(updated) => {
          setOpen(false);
          onUpdated(updated);
        }}
      />
    </AdminCard>
  );
}

function Detail({
  application,
  onAction,
  canGrant,
  onUpdated,
}: {
  application: AdminPartnerApplication;
  onAction: (action: AdminPartnerAction) => void;
  canGrant: boolean;
  onUpdated: (updated: AdminPartnerApplication) => void;
}) {
  const actions = actionsFor[application.status];
  const consentStatus = application.consent_withdrawn_at
    ? `Withdrawn ${formatAdminDateTime(application.consent_withdrawn_at)}`
    : "Active";
  return (
    <div className="flex flex-col gap-4">
      <AdminCard>
        <div className="flex items-start gap-3">
          <AvatarCircle initials={initials(application.name)} size="sm" />
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold">{application.name}</h2>
            <p className="truncate text-sm text-muted-foreground">
              <a
                className="font-semibold text-accent-ink hover:underline"
                href={`https://www.tiktok.com/@${application.tiktok_handle}`}
                target="_blank"
                rel="noreferrer"
              >
                @{application.tiktok_handle}
              </a>{" "}
              · {application.niche}
            </p>
            <p className="mt-0.5 truncate text-xs text-muted-foreground">
              {application.email} · <span className="font-mono">{application.reference}</span>
            </p>
          </div>
          <StatusBadge status={application.status} />
        </div>
        {application.other_channel_url ? (
          <a
            href={application.other_channel_url}
            target="_blank"
            rel="noreferrer"
            className="mt-3 inline-flex items-center gap-1.5 text-sm font-semibold text-accent-ink hover:underline"
          >
            <ExternalLink className="size-3.5" />
            Other channel
          </a>
        ) : null}
      </AdminCard>

      <AdminCard title="Submitted story">
        <div className="flex flex-col gap-4 sm:flex-row">
          <div className="sm:w-[160px] sm:shrink-0">
            <Photo application={application} />
          </div>
          <blockquote className="whitespace-pre-wrap text-sm leading-relaxed">
            “{application.story}”
          </blockquote>
        </div>
        {application.published_at ? (
          <p className="mt-3 text-xs text-muted-foreground">
            Published {formatAdminDateTime(application.published_at)}
          </p>
        ) : null}
      </AdminCard>

      <AdminCard
        title="Consent record"
        description={
          <>
            Stored exactly as the applicant confirmed it.{" "}
            <Link to="/privacy" hash="section-10" className="text-accent-ink hover:underline">
              Privacy Policy §10
            </Link>
          </>
        }
      >
        <ul className="mb-4 flex flex-col gap-2 text-sm">
          {application.consent_texts.map((text) => (
            <li key={text} className="flex items-start gap-2">
              <span className="mt-1.5 size-1.5 shrink-0 rounded-full bg-success" aria-hidden />
              {text}
            </li>
          ))}
        </ul>
        <dl className="grid gap-x-4 gap-y-2.5 text-sm sm:grid-cols-[140px_1fr]">
          <dt className="text-muted-foreground">Timestamp</dt>
          <dd className="font-mono text-[13px]">{formatAdminDateTime(application.created_at)}</dd>
          <dt className="text-muted-foreground">IP address</dt>
          <dd className="font-mono text-[13px]">{application.consent_ip ?? "—"}</dd>
          <dt className="text-muted-foreground">Policy version</dt>
          <dd className="font-mono text-[13px]">
            privacy-{application.privacy_version} · terms-{application.terms_version}
          </dd>
          <dt className="text-muted-foreground">Browser</dt>
          <dd className="break-words text-[13px]">{application.consent_user_agent ?? "—"}</dd>
          <dt className="text-muted-foreground">Consent status</dt>
          <dd>
            <AdminBadge tone={application.consent_withdrawn_at ? "danger" : "success"}>
              {consentStatus}
            </AdminBadge>
          </dd>
        </dl>
      </AdminCard>

      <RewardCard application={application} canGrant={canGrant} onUpdated={onUpdated} />

      <AdminCard>
        {actions.length ? (
          <div className="flex flex-wrap gap-2">
            {actions.map((action) => (
              <Button
                key={action}
                variant={actionCopy[action].variant}
                onClick={() => onAction(action)}
              >
                {actionCopy[action].label}
              </Button>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            Consent was withdrawn. This application is closed.
          </p>
        )}
        <p className="mt-3 text-xs text-muted-foreground">
          All actions ask for a reason and are written to the Audit log as{" "}
          <code className="font-mono">partner.*</code>.
        </p>
      </AdminCard>
    </div>
  );
}

export function AdminPartnersPage() {
  const { identity } = useAuth();
  const canUse = ["owner", "admin", "support"].includes(identity.role);
  // Granting credits needs admin:credits:adjust (Owner; Support does not have it).
  const canGrant = ["owner", "admin"].includes(identity.role);
  const [status, setStatus] = useState<AdminPartnerStatus | "">("pending");
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<AdminPartnerApplication[]>([]);
  const [counts, setCounts] = useState<Partial<Record<AdminPartnerStatus, number>>>({});
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [action, setAction] = useState<AdminPartnerAction | null>(null);
  const [busy, setBusy] = useState(true);

  const load = async (nextStatus = status, nextQuery = query) => {
    setBusy(true);
    try {
      const result = await adminPartnersApi.list({ status: nextStatus, query: nextQuery });
      setItems(result.items);
      setCounts(result.counts);
      setSelectedId((current) =>
        current && result.items.some((item) => item.id === current)
          ? current
          : (result.items[0]?.id ?? null),
      );
    } catch (error) {
      toast.error("Could not load partner applications", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    if (canUse) void load();
    else setBusy(false);
    // Filters are applied explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canUse]);

  const pick = (next: AdminPartnerStatus | "") => {
    setStatus(next);
    void load(next, query);
  };

  const selected = items.find((item) => item.id === selectedId) ?? null;
  const total = Object.values(counts).reduce((sum, value) => sum + (value ?? 0), 0);

  if (!canUse) {
    return (
      <AppShell>
        <PageHeader title="Partners" subtitle="Partner Program applications." />
        <div className="rounded-[16px] border bg-surface p-6">
          <h2 className="font-medium">Permission required</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Partner applications are available to Support and Owner administrators.
          </p>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell>
      <PageHeader
        title="Partners"
        subtitle="Partner Program applications and creator stories."
        action={
          <div className="flex gap-2">
            <Button variant="outline" disabled={busy} onClick={() => void load()}>
              <RefreshCw className="size-4" />
              Refresh
            </Button>
            <Button variant="outline" asChild>
              <a href="/partners/apply" target="_blank" rel="noreferrer">
                <ExternalLink className="size-4" />
                View public form
              </a>
            </Button>
          </div>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-2">
        {filterChips.map(([value, label]) => {
          const count = value ? (counts[value] ?? 0) : total;
          return (
            <button
              key={value || "all"}
              type="button"
              aria-pressed={status === value}
              onClick={() => pick(value)}
              className={cn(
                "inline-flex h-8 items-center gap-1.5 rounded-full border px-3 text-[13px] font-semibold",
                status === value
                  ? "border-primary bg-primary-subtle text-accent-ink"
                  : "bg-surface text-muted-foreground hover:text-foreground",
              )}
            >
              {label}
              <span className="font-mono text-xs">{count}</span>
            </button>
          );
        })}
        <form
          className="ml-auto flex w-full items-center gap-2 sm:w-auto"
          onSubmit={(event) => {
            event.preventDefault();
            void load();
          }}
        >
          <div className="relative w-full sm:w-[260px]">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              className="pl-9"
              placeholder="Search name, handle, email"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </div>
        </form>
      </div>

      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,440px)]">
        <AdminDataTable tableClassName="min-w-[560px]">
          <thead>
            <tr>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">TikTok</th>
              <th className="px-4 py-3">Niche</th>
              <th className="px-4 py-3">Submitted</th>
              <th className="px-4 py-3">Status</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr
                key={item.id}
                aria-selected={item.id === selectedId}
                onClick={() => setSelectedId(item.id)}
                className={cn(
                  "cursor-pointer border-t",
                  item.id === selectedId && "bg-primary-subtle/50",
                )}
              >
                <td className="px-4 py-3">
                  <button
                    type="button"
                    className="flex items-center gap-2.5 text-left font-semibold"
                    onClick={() => setSelectedId(item.id)}
                  >
                    <AvatarCircle initials={initials(item.name)} size="xs" />
                    {item.name}
                  </button>
                </td>
                <td className="px-4 py-3 text-muted-foreground">@{item.tiktok_handle}</td>
                <td className="px-4 py-3">{item.niche}</td>
                <td className="whitespace-nowrap px-4 py-3 text-muted-foreground">
                  {shortDate(item.created_at)}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={item.status} />
                </td>
              </tr>
            ))}
            {!items.length ? (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-muted-foreground">
                  {busy ? "Loading…" : "No applications match this filter."}
                </td>
              </tr>
            ) : null}
          </tbody>
        </AdminDataTable>

        {selected ? (
          <Detail
            application={selected}
            onAction={setAction}
            canGrant={canGrant}
            onUpdated={(updated) =>
              setItems((current) =>
                current.map((item) => (item.id === updated.id ? updated : item)),
              )
            }
          />
        ) : (
          <div className="rounded-[18px] border border-dashed bg-surface p-8 text-center text-sm text-muted-foreground">
            Select an application to review it.
          </div>
        )}
      </div>

      {selected ? (
        <ActionDialog
          application={selected}
          action={action}
          onClose={() => setAction(null)}
          onDone={(updated) => {
            setAction(null);
            setItems((current) => current.map((item) => (item.id === updated.id ? updated : item)));
            void load();
          }}
        />
      ) : null}
    </AppShell>
  );
}
