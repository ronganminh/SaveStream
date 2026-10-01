import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { BillingCanceledPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/billing/canceled")({ head:()=>meta("Checkout canceled","No changes were made to your SaveStream plan."), component:BillingCanceledPage });