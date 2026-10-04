import { createFileRoute } from "@tanstack/react-router";

import { AdminMfaGate } from "@/components/admin/foundation";
import { AdminSafetyD8Page } from "@/components/admin/safety-d8";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/safety")({
  head: () =>
    meta(
      "Safety",
      "Review complaints, creator restrictions, and suspicious account signals.",
    ),
  component: SafetyRoutePage,
});

function SafetyRoutePage() {
  return (
    <AdminMfaGate>
      <AdminSafetyD8Page />
    </AdminMfaGate>
  );
}
