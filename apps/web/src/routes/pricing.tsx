import { createFileRoute } from "@tanstack/react-router";
import { PricingPage } from "@/components/app-pages";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/pricing")({
  head: () =>
    publicMeta("/pricing", "Pricing — Pay only for what you record", "One-time credit packs paid with PayPal. No subscription, and credits never expire. Start with free trial credits.", "pricing"),
  component: PricingPage,
});
