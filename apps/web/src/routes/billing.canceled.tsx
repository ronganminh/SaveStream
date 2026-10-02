import { createFileRoute } from "@tanstack/react-router";

import { BillingCanceledPage } from "@/components/app-pages-more";
import { meta } from "@/components/app-pages";

type BillingReturnSearch = {
  order_id: string;
};

export const Route = createFileRoute("/billing/canceled")({
  validateSearch: (search: Record<string, unknown>): BillingReturnSearch => ({
    order_id: typeof search["order_id"] === "string" ? search["order_id"] : "",
  }),
  head: () => meta("Checkout status", "Review your SaveStream payment-order status."),
  component: BillingCanceledRoute,
});

function BillingCanceledRoute() {
  const search = Route.useSearch();
  return <BillingCanceledPage orderId={search.order_id} />;
}
