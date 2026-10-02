import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { HelpPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/help")({ head:()=>meta("Help","Learn how cloud monitoring, recording lifecycle, credits, and retention work."), component:HelpPage });