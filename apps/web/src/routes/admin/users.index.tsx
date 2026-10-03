import { createFileRoute } from "@tanstack/react-router";

import { AdminUsersPage } from "@/components/admin/user-support";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/users/")({
  head: () => meta("Users", "Admin user support and privacy requests."),
  component: AdminUsersPage,
});
