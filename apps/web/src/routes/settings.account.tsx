import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/settings/account")({ head:()=>meta("Account settings","Update your name, email, profile image, or delete your account."), component:()=> <SettingsPage section="account"/> });