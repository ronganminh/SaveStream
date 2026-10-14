import { createFileRoute } from "@tanstack/react-router";

import { PublicReportPage, type ReportType } from "@/components/public/report";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/report")({
  validateSearch: (search: Record<string, unknown>): { type?: ReportType } =>
    search["type"] === "abuse" ? { type: "abuse" } : {},
  head: () =>
    publicMeta(
      "/report",
      "Report content",
      "Send a copyright notice or report a TikTok LIVE being recorded without permission.",
    ),
  component: ReportRoute,
});

function ReportRoute() {
  const { type } = Route.useSearch();
  return <PublicReportPage type={type ?? "copyright"} />;
}
