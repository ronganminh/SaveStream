import type { ReactNode } from "react";

import { AdminSystemPage as LegacyAdminSystemPage } from "@/components/app-pages";
import {
  AdminErrorsPage as LegacyAdminErrorsPage,
  AdminJobDetailPage as LegacyAdminJobDetailPage,
  AdminJobsPage as LegacyAdminJobsPage,
  AdminWorkersPage as LegacyAdminWorkersPage,
} from "@/components/app-pages-more";
import { AdminMfaGate } from "@/components/admin/foundation";

function ProtectedAdminPage({ children }: { children: ReactNode }) {
  return <AdminMfaGate>{children}</AdminMfaGate>;
}

export function AdminSystemPage() {
  return (
    <ProtectedAdminPage>
      <LegacyAdminSystemPage />
    </ProtectedAdminPage>
  );
}

export function AdminWorkersPage() {
  return (
    <ProtectedAdminPage>
      <LegacyAdminWorkersPage />
    </ProtectedAdminPage>
  );
}

export function AdminJobsPage() {
  return (
    <ProtectedAdminPage>
      <LegacyAdminJobsPage />
    </ProtectedAdminPage>
  );
}

export function AdminJobDetailPage() {
  return (
    <ProtectedAdminPage>
      <LegacyAdminJobDetailPage />
    </ProtectedAdminPage>
  );
}

export function AdminErrorsPage() {
  return (
    <ProtectedAdminPage>
      <LegacyAdminErrorsPage />
    </ProtectedAdminPage>
  );
}
