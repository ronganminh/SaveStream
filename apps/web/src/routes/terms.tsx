import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { TermsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/terms")({ head:()=>meta("Terms of Service","The terms for using SaveStream cloud livestream recording."), component:TermsPage });