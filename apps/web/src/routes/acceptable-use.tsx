import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { AcceptableUsePage } from "@/components/app-pages-more";
export const Route = createFileRoute("/acceptable-use")({ head:()=>meta("Acceptable Use Policy","Record only TikTok channels you own, manage, or have permission to record."), component:AcceptableUsePage });