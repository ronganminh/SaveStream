import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { AdminWorkersPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/admin/workers")({ head:()=>meta("Workers","Recorder and processor worker health and heartbeats."), component:AdminWorkersPage });