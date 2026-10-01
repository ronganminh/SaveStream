import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { StatusPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/status")({
  head: () => {
    const base = meta(
      "System status preview",
      "Illustrative SaveStream status UI. This frontend prototype is not connected to live monitoring.",
    );
    return {
      ...base,
      meta: [...base.meta, { name: "robots", content: "noindex,nofollow" }],
    };
  },
  component: StatusPage,
});
