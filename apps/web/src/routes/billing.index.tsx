import { createFileRoute } from "@tanstack/react-router";
import { BillingPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/billing/")({ head:()=>meta("Billing","Manage your SaveStream plan, payment method, and invoices."), component:BillingPage });