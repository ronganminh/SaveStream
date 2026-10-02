import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { StatusPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/status")({
  head: () => {
    const base = meta(
      "System status",
      "Public live incident data is not currently published by the SaveStream production backend.",
    );
    return {
      ...base,
      meta: [...base.meta, { name: "robots", content: "noindex,nofollow" }],
    };
  },
  component: StatusPage,
});
