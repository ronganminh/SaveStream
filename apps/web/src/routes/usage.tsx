import { createFileRoute } from "@tanstack/react-router";
import { UsagePage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/usage")({ head:()=>meta("Usage","Review recording hours, downloads, retention, and monthly plan limits."), component:UsagePage });