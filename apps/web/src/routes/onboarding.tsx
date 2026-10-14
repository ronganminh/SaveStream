import { createFileRoute } from "@tanstack/react-router";
import { OnboardingPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/onboarding")({
  head: () => meta("Get started", "Add your first TikTok channel for automatic monitoring."),
  validateSearch: (search: Record<string, unknown>): { step?: number } => {
    const step = Number(search["step"]);
    return Number.isInteger(step) && step >= 1 && step <= 4 ? { step } : {};
  },
  component: OnboardingPage,
});
