import { createFileRoute } from "@tanstack/react-router";
import { RefundPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/refund")({
  head: () =>
    publicMeta("/refund", "Refund Policy", "When and how SaveStream credit-pack purchases can be refunded, and how to ask for a refund."),
  component: () => <RefundPage />,
});
