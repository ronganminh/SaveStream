import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { PrivacyPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/privacy")({ head:()=>meta("Privacy Policy","How SaveStream handles account data and recordings."), component:PrivacyPage });