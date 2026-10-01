import { createFileRoute } from "@tanstack/react-router";
import { AuthPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/sign-in")({ head:()=>meta("Sign in","Sign in to manage monitored channels and cloud recordings."), component:()=> <AuthPage mode="sign-in"/> });