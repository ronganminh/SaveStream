import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { VerifyEmailSuccessPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/verify-email/success")({ head:()=>meta("Email verified","Your SaveStream account is active."), component:VerifyEmailSuccessPage });