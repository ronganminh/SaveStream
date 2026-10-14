import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { HelpArticlePage } from "@/components/public/help-pages";
import { helpArticle } from "@/lib/help-content";

export const Route = createFileRoute("/help/$article")({
  head: ({ params }) => {
    const article = helpArticle(params.article);
    return publicMeta(
      `/help/${params.article}`,
      article ? `${article.title} | SaveStream Help` : "Help article",
      article?.summary || "SaveStream help article.",
      "help",
    );
  },
  component: HelpArticleRoute,
});

function HelpArticleRoute() {
  const { article } = Route.useParams();
  return <HelpArticlePage slug={article} />;
}
