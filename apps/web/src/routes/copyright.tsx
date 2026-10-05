import { createFileRoute } from "@tanstack/react-router";
import { CopyrightPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/copyright")({
  head: () =>
    publicMeta(
      "/copyright",
      "Copyright & Takedown Policy",
      "How rights holders can report alleged infringement involving SaveStream processing or storage.",
    ),
  component: () => <CopyrightPage />,
});
