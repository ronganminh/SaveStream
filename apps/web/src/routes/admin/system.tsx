import { createFileRoute } from "@tanstack/react-router";
import { AdminSystemPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/admin/system")({ head:()=>meta("System health","Monitor recording infrastructure and service health."), component:AdminSystemPage });