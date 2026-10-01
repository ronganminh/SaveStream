import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/settings/notifications")({ head:()=>meta("Notification settings","Choose which recording and quota emails you receive."), component:()=> <SettingsPage section="notifications"/> });