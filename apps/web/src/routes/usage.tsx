import { createFileRoute } from "@tanstack/react-router";
import { UsagePage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/usage")({
  head: () => meta("Usage", "Review your credit balance, reserved credits, and recording charges."),
  component: UsagePage,
});
