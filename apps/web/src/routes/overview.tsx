import { createFileRoute } from "@tanstack/react-router";
import { OverviewPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/overview")({ head:()=>meta("Overview","Monitor active cloud recordings, channel health, and monthly usage."), component:OverviewPage });