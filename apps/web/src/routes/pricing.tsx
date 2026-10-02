import { createFileRoute } from "@tanstack/react-router";
import { PricingPage } from "@/components/app-pages";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/pricing")({
  head: () =>
    publicMeta(
      "/pricing",
      "Pricing",
      "Pay-as-you-go credit packages for cloud TikTok livestream recording. One-time purchase, credits never expire.",
    ),
  component: PricingPage,
});
