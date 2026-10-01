import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { AuthErrorPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/auth/error")({ head:()=>meta("Link problem","This sign-in, verification, or reset link is expired or invalid."), component:AuthErrorPage });