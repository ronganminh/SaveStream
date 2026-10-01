import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { HelpPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/help")({ head:()=>meta("Help","Learn how cloud monitoring, recording, quotas, and retention work."), component:HelpPage });