import { createFileRoute } from "@tanstack/react-router";
import { AuthPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/sign-up")({ head:()=>meta("Create account","Create a SaveStream account and monitor your first authorized channel."), component:()=> <AuthPage mode="sign-up"/> });