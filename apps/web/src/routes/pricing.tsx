import { createFileRoute } from "@tanstack/react-router";
import { PricingPage } from "@/components/app-pages";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/pricing")({
  head: () => publicMeta("/pricing", "Pricing", "Credit-based SaveStream pricing backed by the active recording and billing configuration."),
  component: PricingPage,
});
