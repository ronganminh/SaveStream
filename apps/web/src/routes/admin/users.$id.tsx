import { createFileRoute } from "@tanstack/react-router";

import { AdminUserDetailPage } from "@/components/admin/user-support";
import { meta } from "@/components/app-pages";

function UserDetailRoute() {
  const { id } = Route.useParams();
  return <AdminUserDetailPage userId={id} />;
}

export const Route = createFileRoute("/admin/users/$id")({
  head: () => meta("User support", "Admin user detail and support actions."),
  component: UserDetailRoute,
});
