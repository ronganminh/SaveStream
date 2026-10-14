import { createFileRoute } from "@tanstack/react-router";
import { ContactPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/contact")({
  head: () =>
    publicMeta("/contact", "Contact support", "Questions about a recording, a payment or your account? Email support@savestream.online."),
  component: () => <ContactPage />,
});
