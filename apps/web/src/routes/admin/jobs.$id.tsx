import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { AdminJobDetailPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/admin/jobs/$id")({ head:()=>meta("Job detail","Timeline, context, and errors for a recording job."), component:AdminJobDetailPage });