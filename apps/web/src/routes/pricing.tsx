import { createFileRoute } from "@tanstack/react-router";
import { PricingPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/pricing")({ head:()=>meta("Pricing","Simple Free and Pro plans for automatic cloud livestream recording."), component:PricingPage });