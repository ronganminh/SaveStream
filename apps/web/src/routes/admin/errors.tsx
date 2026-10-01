import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { AdminErrorsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/admin/errors")({ head:()=>meta("Errors & events","System error and event log across recording infrastructure."), component:AdminErrorsPage });