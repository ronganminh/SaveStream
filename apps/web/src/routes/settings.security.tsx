import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/settings/security")({ head:()=>meta("Security settings","Change your password and manage active sessions."), component:()=> <SettingsPage section="security"/> });