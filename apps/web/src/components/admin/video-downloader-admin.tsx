import { useEffect, useState } from "react";
import { Ban, RefreshCw, ShieldAlert, Unlock } from "lucide-react";
import { toast } from "sonner";

import { authErrorMessage } from "@/api/auth";
import { AdminBadge, AdminDataTable } from "@/components/admin/foundation";
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
import { formatAdminDateTime } from "@/lib/formatters";
import {
  adminFoundationApi,
  adminVideoDownloaderApi,
  type AdminVideoDownloaderBlock,
  type AdminVideoDownloaderReport,
} from "@/repositories/admin-api";

// Admin › Safety › Downloader: the video downloader's blocklist and the
// report / copyright removal requests (a report blocks its video at once).
// Writes use the same step-up confirmation as the creator blocks.

type DownloaderAction =
  | { mode: "block"; videoUrl: string; reason: string }
  | { mode: "unblock"; block: AdminVideoDownloaderBlock };

function DownloaderBlockDialog({
  action,
  onClose,
  onDone,
}: {
  action: DownloaderAction | null;
  onClose: () => void;
  onDone: () => Promise<void> | void;
}) {
  const [videoUrl, setVideoUrl] = useState("");
  const [reason, setReason] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!action) return;
    setVideoUrl(action.mode === "block" ? action.videoUrl : "");
    setReason(action.mode === "block" ? action.reason : "");
    setPassword("");
    setTotp("");
    setError(null);
  }, [action]);

  const blockMode = action?.mode === "block";

  const submit = async () => {
    if (!action) return;
    setBusy(true);
    setError(null);
    try {
      const stepUp = await adminFoundationApi.stepUp(password, totp);
      if (action.mode === "block") {
        await adminVideoDownloaderApi.block(videoUrl.trim(), reason.trim(), stepUp.token);
        toast.success("Video blocked in the downloader");
      } else {
        await adminVideoDownloaderApi.unblock(action.block.video_id, reason.trim(), stepUp.token);
        toast.success("Video unblocked in the downloader");
      }
      await onDone();
      onClose();
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  const valid =
    reason.trim().length >= 3 &&
    password.length > 0 &&
    totp.trim().length === 6 &&
    (!blockMode || videoUrl.trim().length > 0);

  return (
    <Dialog open={action !== null} onOpenChange={(next) => !next && !busy && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {blockMode ? "Block a video in the downloader?" : "Unblock this video?"}
          </DialogTitle>
          <DialogDescription>
            {blockMode
              ? "Visitors can no longer fetch this video with the video downloader."
              : "The video can be fetched again if its creator allows downloads."}{" "}
            Requires password re-entry, an authenticator code and a reason; permanently audited.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          {blockMode ? (
            <div className="space-y-1">
              <label htmlFor="dl-block-url" className="text-sm font-medium">
                TikTok video link <span className="text-destructive">*</span>
              </label>
              <Input
                id="dl-block-url"
                type="url"
                placeholder="https://www.tiktok.com/@name/video/…"
                value={videoUrl}
                onChange={(event) => setVideoUrl(event.target.value)}
              />
            </div>
          ) : (
            <p className="break-all rounded-md bg-surface-2 px-3 py-2 font-mono text-xs">
              {action?.mode === "unblock" ? action.block.video_url : null}
            </p>
          )}
          <div className="space-y-1">
            <label htmlFor="dl-block-reason" className="text-sm font-medium">
              Reason <span className="text-destructive">*</span>
            </label>
            <Input
              id="dl-block-reason"
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
            {busy ? "Confirming…" : blockMode ? "Block video" : "Unblock"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

const relationshipLabel: Record<AdminVideoDownloaderReport["relationship"], string> = {
  creator: "Creator",
  rights_holder: "Rights holder",
  agent: "Agent",
  other: "Other",
};

function VideoLink({ url }: { url: string }) {
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer nofollow"
      className="block max-w-[280px] truncate font-mono text-xs text-accent-ink hover:underline"
      title={url}
    >
      {url}
    </a>
  );
}

export function VideoDownloaderAdminTab({ canWrite = true }: { canWrite?: boolean }) {
  const [blocks, setBlocks] = useState<AdminVideoDownloaderBlock[]>([]);
  const [reports, setReports] = useState<AdminVideoDownloaderReport[]>([]);
  const [busy, setBusy] = useState(true);
  const [action, setAction] = useState<DownloaderAction | null>(null);

  const load = async () => {
    setBusy(true);
    try {
      const [blockResult, reportResult] = await Promise.all([
        adminVideoDownloaderApi.listBlocklist(true),
        adminVideoDownloaderApi.listReports(50),
      ]);
      setBlocks(blockResult.items);
      setReports(reportResult.items);
    } catch (error) {
      toast.error("Could not load the downloader blocklist", {
        description: authErrorMessage(error),
      });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="max-w-2xl text-sm text-muted-foreground">
          Videos blocked in the public video downloader. A report from the removal form blocks its
          video immediately; unblock only after reviewing it.
        </p>
        <div className="flex gap-2">
          <Button variant="outline" disabled={busy} onClick={() => void load()}>
            <RefreshCw className="size-4" />
            Refresh
          </Button>
          {canWrite && (
            <Button onClick={() => setAction({ mode: "block", videoUrl: "", reason: "" })}>
              <ShieldAlert className="size-4" />
              Block a video
            </Button>
          )}
        </div>
      </div>

      <section className="space-y-3" aria-labelledby="dl-blocklist">
        <h3 id="dl-blocklist" className="font-bold">
          Blocked videos
        </h3>
        <AdminDataTable>
          <thead>
            <tr className="border-b">
              <th className="px-4 py-3">Video</th>
              <th className="px-4 py-3">Reason</th>
              <th className="px-4 py-3">Source</th>
              <th className="px-4 py-3">Blocked</th>
              <th className="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {blocks.map((block) => (
              <tr key={block.video_id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <VideoLink url={block.video_url} />
                  <p className="mt-1 font-mono text-[11px] text-muted-foreground">
                    {block.video_id}
                  </p>
                </td>
                <td className="max-w-sm truncate px-4 py-3 text-sm" title={block.reason}>
                  {block.reason}
                </td>
                <td className="px-4 py-3">
                  <AdminBadge tone={block.source === "report" ? "warning" : "neutral"}>
                    {block.source}
                  </AdminBadge>
                  {block.report_reference ? (
                    <span className="ml-2 font-mono text-xs">{block.report_reference}</span>
                  ) : null}
                </td>
                <td className="px-4 py-3 text-xs">{formatAdminDateTime(block.blocked_at)}</td>
                <td className="px-4 py-3">
                  <div className="flex justify-end">
                    {canWrite && !block.unblocked_at ? (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setAction({ mode: "unblock", block })}
                      >
                        <Unlock className="size-3" />
                        Unblock
                      </Button>
                    ) : (
                      <span className="text-xs text-muted-foreground">
                        {block.unblocked_at
                          ? `Unblocked ${formatAdminDateTime(block.unblocked_at)}`
                          : "—"}
                      </span>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {!blocks.length && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-sm text-muted-foreground">
                  {busy ? "Loading blocked videos…" : "No videos are blocked in the downloader."}
                </td>
              </tr>
            )}
          </tbody>
        </AdminDataTable>
      </section>

      <section className="space-y-3" aria-labelledby="dl-reports">
        <h3 id="dl-reports" className="font-bold">
          Removal requests
        </h3>
        <AdminDataTable>
          <thead>
            <tr className="border-b">
              <th className="px-4 py-3">Reference</th>
              <th className="px-4 py-3">Video</th>
              <th className="px-4 py-3">Reporter</th>
              <th className="px-4 py-3">Reason</th>
              <th className="px-4 py-3">Received</th>
              <th className="px-4 py-3 text-right">Status</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report) => (
              <tr key={report.reference} className="border-b align-top last:border-0">
                <td className="px-4 py-3 font-mono text-xs font-bold">{report.reference}</td>
                <td className="px-4 py-3">
                  <VideoLink url={report.video_url} />
                </td>
                <td className="px-4 py-3 text-sm">
                  <p className="font-bold">{report.reporter_name}</p>
                  <p className="text-xs text-muted-foreground">{report.reporter_email}</p>
                  <p className="text-xs text-muted-foreground">
                    {relationshipLabel[report.relationship] ?? report.relationship}
                  </p>
                </td>
                <td className="max-w-xs px-4 py-3 text-sm">
                  <AdminBadge tone={report.reason === "copyright" ? "accent" : "warning"}>
                    {report.reason}
                  </AdminBadge>
                  {report.details ? (
                    <p
                      className="mt-1 line-clamp-2 whitespace-pre-line text-xs text-muted-foreground"
                      title={report.details}
                    >
                      {report.details}
                    </p>
                  ) : null}
                </td>
                <td className="px-4 py-3 text-xs">{formatAdminDateTime(report.created_at)}</td>
                <td className="px-4 py-3">
                  <div className="flex justify-end">
                    {report.blocked ? (
                      <AdminBadge tone="danger" dot>
                        blocked
                      </AdminBadge>
                    ) : canWrite ? (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() =>
                          setAction({
                            mode: "block",
                            videoUrl: report.video_url,
                            reason: `Removal request ${report.reference}`,
                          })
                        }
                      >
                        <Ban className="size-3" />
                        Block
                      </Button>
                    ) : (
                      <AdminBadge tone="neutral">not blocked</AdminBadge>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {!reports.length && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-sm text-muted-foreground">
                  {busy ? "Loading removal requests…" : "No removal requests yet."}
                </td>
              </tr>
            )}
          </tbody>
        </AdminDataTable>
      </section>

      <DownloaderBlockDialog action={action} onClose={() => setAction(null)} onDone={load} />
    </div>
  );
}
