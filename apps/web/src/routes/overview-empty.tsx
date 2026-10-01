import { createFileRoute } from "@tanstack/react-router";
import { OverviewPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/overview-empty")({ head:()=>meta("Overview — No active recordings","Monitor enabled channels while waiting for the next livestream."), component:()=> <OverviewPage empty/> });