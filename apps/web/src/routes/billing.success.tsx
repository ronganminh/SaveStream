import { createFileRoute } from "@tanstack/react-router";

import { BillingSuccessPage } from "@/components/app-pages-more";
import { meta } from "@/components/app-pages";

type BillingReturnSearch = {
  order_id: string;
};

export const Route = createFileRoute("/billing/success")({
  validateSearch: (search: Record<string, unknown>): BillingReturnSearch => ({
    order_id: typeof search["order_id"] === "string" ? search["order_id"] : "",
  }),
  head: () => meta("Payment confirmation", "Confirm your SaveStream credit purchase."),
  component: BillingSuccessRoute,
});

function BillingSuccessRoute() {
  const search = Route.useSearch();
  return <BillingSuccessPage orderId={search.order_id} />;
}
