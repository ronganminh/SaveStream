import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { BillingSuccessPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/billing/success")({ head:()=>meta("You’re on Pro","Your SaveStream Pro subscription is active."), component:BillingSuccessPage });