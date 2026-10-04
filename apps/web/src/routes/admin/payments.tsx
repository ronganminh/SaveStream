import { createFileRoute } from "@tanstack/react-router";

import { AdminFinancePage } from "@/components/admin/payments-d2";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/payments")({
  head: () => meta("Payments & cloud minutes", "Finance administration for SaveStream."),
  component: AdminFinancePage,
});
