import { formatAdminDateTime } from "@/lib/formatters";
import { useEffect, useState } from "react";
import { Unlock } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { AdminDataTable } from "@/components/admin/foundation";
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
  adminSafetyApi,
  type AdminChannelAccountBlock,
} from "@/repositories/admin-api";

// Per-account channel blocks: stop ONE account from recording ONE channel
// after a report (other accounts are not affected). Same step-up and
// confirmation pattern as the global creator blocks in Safety.

export type ChannelAccountBlockAction =
  | {
      mode: "block";
      watchId: string;
      /** "@username" of the channel. */
      channel: string;
      /** Email or name of the account, for the confirmation text. */
      account: string;
      /** Prefilled when opened from a complaint; optional otherwise. */
      complaintId?: string | null;
    }
  | { mode: "unblock"; block: AdminChannelAccountBlock };

export function ChannelAccountBlockDialog({
  action,
  onClose,
  onDone,
}: {
  action: ChannelAccountBlockAction | null;
  onClose: () => void;
  onDone: () => Promise<void> | void;
}) {
  const [complaintId, setComplaintId] = useState("");
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!action) return;
    setComplaintId(action.mode === "block" ? (action.complaintId ?? "") : "");
    setReason("");
    setPassword("");
    setTotp("");
    setError(null);
  }, [action]);

  const submit = async () => {
    if (!action) return;
    setBusy(true);
    setError(null);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      if (action.mode === "block") {
        const result = await adminSafetyApi.blockChannelForAccount(
          action.watchId,
          { reason: reason.trim(), complaint_id: complaintId.trim() || null },
          stepUp.token,
        );
        toast.success(`${action.channel} blocked for this account`, {
          description: `${result.stopped_recording_ids.length} recording(s) stopped, ${result.paused_watch_ids.length} channel(s) paused.`,
        });
      } else {
        await adminSafetyApi.unblockChannelAccount(action.block.id, reason.trim(), stepUp.token);
        toast.success(`@${action.block.username} unblocked for this account`);
      }
      await onDone();
      onClose();
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  const valid = reason.trim().length >= 3 && password.length > 0 && totp.trim().length === 6;
  const blockMode = action?.mode === "block";

  return (
    <Dialog open={action !== null} onOpenChange={(next) => !next && !busy && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {action?.mode === "block"
              ? `Block ${action.channel} for this account?`
              : action?.mode === "unblock"
                ? `Unblock @${action.block.username} for this account?`
                : "Channel block"}
          </DialogTitle>
          <DialogDescription>
            {action?.mode === "block"
              ? `${action.account} can no longer record ${action.channel}: active recordings stop and the channel is paused. Other accounts are not affected. The user sees “Recording stopped for this channel on your account after a report.”`
              : action?.mode === "unblock"
                ? "The user can resume monitoring and recording this channel. Paused channels are not resumed automatically."
                : null}{" "}
            Requires password re-entry, an authenticator code and a reason; permanently audited.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          {blockMode && (
            <div className="space-y-1">
              <label htmlFor="channel-block-complaint" className="text-sm font-medium">
                Complaint ID <span className="text-muted-foreground">(optional)</span>
              </label>
              <Input
                id="channel-block-complaint"
                placeholder="Link this block to a complaint case"
                value={complaintId}
                onChange={(event) => setComplaintId(event.target.value)}
              />
            </div>
          )}
          <div className="space-y-1">
            <label htmlFor="channel-block-reason" className="text-sm font-medium">
              Reason <span className="text-destructive">*</span>
            </label>
            <Input
              id="channel-block-reason"
              placeholder="Reason (required, at least 3 characters)"
              value={reason}
              onChange={(event) => setReason(event.target.value)}
            />
          </div>
          <Input
            type="password"
            placeholder="Password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <Input
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            placeholder="Authenticator code"
            value={totp}
            onChange={(event) => setTotp(event.target.value)}
          />
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
        </div>
        <DialogFooter>
          <Button variant="outline" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={blockMode ? "destructive" : "default"}
            disabled={!valid || busy}
            onClick={() => void submit()}
          >
            {busy ? "Confirming…" : blockMode ? "Block for this account" : "Unblock"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/** Active per-account channel blocks, each with Unblock. */
export function ChannelAccountBlocksTable({
  blocks,
  busy,
  showAccount = true,
  canWrite = true,
  onUnblock,
}: {
  blocks: AdminChannelAccountBlock[];
  busy?: boolean;
  showAccount?: boolean;
  canWrite?: boolean;
  onUnblock: (block: AdminChannelAccountBlock) => void;
}) {
  const columns = showAccount ? 6 : 5;
  return (
    <AdminDataTable>
      <thead>
        <tr className="border-b">
          <th className="px-4 py-3">Channel</th>
          {showAccount && <th className="px-4 py-3">Account</th>}
          <th className="px-4 py-3">Reason</th>
          <th className="px-4 py-3">Complaint</th>
          <th className="px-4 py-3">Blocked</th>
          <th className="px-4 py-3 text-right">Actions</th>
        </tr>
      </thead>
      <tbody>
        {blocks.map((block) => (
          <tr key={block.id} className="border-b last:border-0">
            <td className="px-4 py-3 font-bold">@{block.username}</td>
            {showAccount && (
              <td className="px-4 py-3 font-mono text-xs">
                <a
                  className="text-accent-ink hover:underline"
                  href={`/admin/users/${block.user_id}`}
                >
                  {block.user_id}
                </a>
              </td>
            )}
            <td className="max-w-sm truncate px-4 py-3 text-sm" title={block.reason}>
              {block.reason}
            </td>
            <td className="px-4 py-3 font-mono text-xs">{block.complaint_id ?? "—"}</td>
            <td className="px-4 py-3 text-xs">{formatAdminDateTime(block.created_at)}</td>
            <td className="px-4 py-3">
              <div className="flex justify-end">
                {block.active && canWrite ? (
                  <Button size="sm" variant="outline" onClick={() => onUnblock(block)}>
                    <Unlock className="size-3" />
                    Unblock
                  </Button>
                ) : (
                  <span className="text-xs text-muted-foreground">
                    {block.active ? "—" : `Unblocked ${formatAdminDateTime(block.unblocked_at)}`}
                  </span>
                )}
              </div>
            </td>
          </tr>
        ))}
        {!blocks.length && (
          <tr>
            <td colSpan={columns} className="px-4 py-8 text-center text-sm text-muted-foreground">
              {busy ? "Loading channel blocks…" : "No active per-account channel blocks."}
            </td>
          </tr>
        )}
      </tbody>
    </AdminDataTable>
  );
}
