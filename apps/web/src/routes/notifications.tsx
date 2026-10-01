import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { NotificationsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/notifications")({ head:()=>meta("Notifications","Recording activity, failures, and quota alerts."), component:NotificationsPage });