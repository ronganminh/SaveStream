import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { GuidePage } from "@/components/public/guides-pages";
import { guide } from "@/lib/guides-content";

export const Route = createFileRoute("/guides/$guide")({
  head: ({ params }) => {
    const item = guide(params.guide);
    return publicMeta(
      `/guides/${params.guide}`,
      item ? item.title : "Guide",
      item?.summary || "SaveStream guide.",
      "help",
      "article",
    );
  },
  component: GuideRoute,
});

function GuideRoute() {
  const { guide: slug } = Route.useParams();
  return <GuidePage slug={slug} />;
}
