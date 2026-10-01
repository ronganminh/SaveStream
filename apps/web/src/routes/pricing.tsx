import { createFileRoute } from "@tanstack/react-router";
import { PricingPage } from "@/components/app-pages";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/pricing")({
  head: () => publicMeta("/pricing", "Pricing", "Simple Free and Pro monthly plans for SaveStream recording workflows."),
  component: PricingPage,
});
