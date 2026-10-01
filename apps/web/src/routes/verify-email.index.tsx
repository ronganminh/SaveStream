import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { VerifyEmailPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/verify-email/")({ head:()=>meta("Check your email","Verify your email address to activate your SaveStream account."), component:VerifyEmailPage });