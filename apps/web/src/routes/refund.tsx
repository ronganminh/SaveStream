import { createFileRoute } from "@tanstack/react-router";
import { RefundPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/refund")({
  head: () =>
    publicMeta(
      "/refund",
      "Refund Policy",
      "How to request a refund for a SaveStream credit purchase processed by our authorized Merchant of Record (MoR).",
    ),
  component: () => <RefundPage />,
});
