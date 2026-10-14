import { createFileRoute } from "@tanstack/react-router";

import { publicMeta } from "@/components/app-pages";
import { PartnerApplyPage } from "@/components/public/partner-apply";

export const Route = createFileRoute("/partners/apply")({
  head: () =>
    publicMeta(
      "/partners/apply",
      "Apply as a partner",
      "Share how you record your own TikTok LIVEs with SaveStream and get featured on our site.",
    ),
  component: PartnerApplyPage,
});
