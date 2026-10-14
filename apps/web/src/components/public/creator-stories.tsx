import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowUpRight, ShieldCheck, Star } from "lucide-react";

import { listPartnerStories, partnerStoryPhotoUrl, type PartnerStory } from "@/api/partners";
import { AvatarCircle } from "@/components/app-components";
import { Button } from "@/components/ui/button";
import { initials } from "@/repositories/mappers/channel";

function StoryCard({ story }: { story: PartnerStory }) {
  const photo = story.has_photo ? partnerStoryPhotoUrl(story.id) : null;
  return (
    <article className="flex flex-col gap-[18px] rounded-2xl border bg-surface p-[22px] shadow-card">
      <div className="flex items-center gap-3">
        <AvatarCircle src={photo} initials={initials(story.name)} size="md" />
        <span className="flex min-w-0 flex-col">
          <b className="truncate text-[15px]">{story.name}</b>
          <span className="truncate text-[13px] text-muted-foreground">@{story.tiktok_handle}</span>
        </span>
        <span className="ml-auto shrink-0 rounded-full bg-primary-subtle px-2.5 py-1 text-xs font-bold text-accent-ink">
          {story.niche}
        </span>
      </div>
      <blockquote className="whitespace-pre-line text-base font-medium leading-relaxed text-pretty">
        “{story.story}”
      </blockquote>
      <div className="mt-auto flex flex-wrap items-center justify-between gap-2.5 border-t pt-3.5 text-[13px]">
        <span className="inline-flex items-center gap-1.5 font-semibold text-success">
          <ShieldCheck className="size-4" />
          Shared with the creator’s permission
        </span>
        <a
          href={`https://www.tiktok.com/@${story.tiktok_handle}`}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-1 font-semibold text-accent-ink hover:underline"
        >
          TikTok
          <ArrowUpRight className="size-3.5" />
        </a>
      </div>
    </article>
  );
}

/**
 * Home page "Creator stories": only published Partner Program stories whose
 * consent is still active. Renders nothing while loading, on error, or when
 * there are no stories.
 */
export function CreatorStories() {
  const { data } = useQuery({
    queryKey: ["public", "partner-stories"],
    queryFn: listPartnerStories,
    staleTime: 5 * 60_000,
    retry: false,
  });
  const stories = data?.items ?? [];
  if (!stories.length) return null;

  return (
    <section id="stories" className="scroll-mt-20 border-b py-24">
      <div className="mx-auto flex max-w-[1240px] flex-col gap-10 px-6">
        <div className="flex flex-col items-center gap-3.5 text-center">
          <span className="text-[13px] font-bold uppercase tracking-[.08em] text-accent-ink">
            Creator stories
          </span>
          <h2 className="text-[clamp(30px,3.4vw,44px)] font-extrabold leading-[1.1] tracking-[-.025em] text-balance">
            Creators who never lose a LIVE
          </h2>
          <p className="max-w-[560px] text-lg leading-relaxed text-muted-foreground">
            Partner creators record their own TikTok LIVEs with SaveStream. Here’s what changed for
            them.
          </p>
        </div>
        <div className="grid gap-6 [grid-template-columns:repeat(auto-fit,minmax(min(360px,100%),1fr))]">
          {stories.map((story) => (
            <StoryCard key={story.id} story={story} />
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-x-6 gap-y-4 rounded-2xl border border-primary/30 bg-gradient-to-r from-primary-subtle to-surface px-6 py-[18px]">
          <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-primary text-primary-foreground">
            <Star className="size-5" />
          </span>
          <p className="m-0 flex-[1_1_420px] text-base">
            <b>Are you a creator?</b> Join the SaveStream Partner Program and share how you record
            your own LIVEs.
          </p>
          <Button asChild>
            <Link to="/partners/apply">Apply as a partner</Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
