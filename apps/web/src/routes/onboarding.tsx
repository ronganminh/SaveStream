import { createFileRoute } from "@tanstack/react-router";
import { OnboardingPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/onboarding")({ head:()=>meta("Onboarding","Add your first TikTok channel for automatic monitoring."), component:OnboardingPage });