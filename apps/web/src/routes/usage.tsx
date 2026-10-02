import { createFileRoute } from "@tanstack/react-router";
import { UsagePage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/usage")({ head:()=>meta("Usage","Review backend-authoritative credit balance, reservations, and recording charges."), component:UsagePage });