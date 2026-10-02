import { createFileRoute } from "@tanstack/react-router";
import { ContactPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/contact")({
  head: () =>
    publicMeta(
      "/contact",
      "Contact",
      "Contact SaveStream support, billing, privacy, and abuse reporting.",
    ),
  component: () => <ContactPage />,
});
