import { createFileRoute } from "@tanstack/react-router";

import { AdminCatalogPage } from "@/components/admin/catalog-d5";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/catalog")({
  head: () => meta("Catalog & promotions", "Package and promotion administration."),
  component: AdminCatalogPage,
});
