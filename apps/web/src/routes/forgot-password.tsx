import { createFileRoute } from "@tanstack/react-router";
import { AuthPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/forgot-password")({ head:()=>meta("Reset password","Request a secure password reset link."), component:()=> <AuthPage mode="forgot"/> });