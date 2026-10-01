import { createFileRoute } from "@tanstack/react-router";
import { AuthPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/reset-password")({ head:()=>meta("Choose new password","Choose a new password for your SaveStream account."), component:()=> <AuthPage mode="reset"/> });