import { createFileRoute } from "@tanstack/react-router";

import { AdminMfaGate } from "@/components/admin/foundation";
import { AdminPartnersPage } from "@/components/admin/partners";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/partners")({
  head: () => meta("Partners", "Review Partner Program applications and creator stories."),
  component: PartnersRoutePage,
});

function PartnersRoutePage() {
  return (
    <AdminMfaGate>
      <AdminPartnersPage />
    </AdminMfaGate>
  );
}
