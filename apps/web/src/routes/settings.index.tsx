import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/settings/")({ head:()=>meta("Settings","Manage account details, recording notifications, and security."), component:()=> <SettingsPage section="account"/> });