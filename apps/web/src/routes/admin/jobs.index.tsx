import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { AdminJobsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/admin/jobs/")({ head:()=>meta("Recording jobs","Inspect active, completed, stuck, and failed recording jobs."), component:AdminJobsPage });