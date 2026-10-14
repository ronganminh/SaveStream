import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { BillingOrderPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/billing/$id")({
  head: () => meta("Order details", "Receipt and payment status for a SaveStream credit purchase."),
  component: BillingOrderRoute,
});

function BillingOrderRoute() {
  const { id } = Route.useParams();
  return <BillingOrderPage orderId={id} />;
}
