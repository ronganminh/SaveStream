import type { ReactNode } from "react";

import { AdminSystemPage as LegacyAdminSystemPage } from "@/components/app-pages";
import {
  AdminErrorsPage as LegacyAdminErrorsPage,
  AdminJobDetailPage as LegacyAdminJobDetailPage,
  AdminWorkersPage as LegacyAdminWorkersPage,
} from "@/components/app-pages-more";
import { AdminMfaGate } from "@/components/admin/foundation";
import { AdminRecordingOperationsPage } from "@/components/admin/recordings-d3";

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
      <AdminRecordingOperationsPage />
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
