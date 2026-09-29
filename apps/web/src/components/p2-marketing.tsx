import { Check, Mail, Play, Quote, Youtube } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { sampleMedia } from "../lib/sample-media";
import { usePreferences, type Locale } from "../lib/preferences";

const PARTNER_CHANNEL = "https://www.youtube.com/channel/UCUkhUF-GUS22KWBFEcD2fEw";

function ensureMeta(selector: string, attrs: Record<string, string>) {
  let element = document.head.querySelector<HTMLMetaElement | HTMLLinkElement>(selector);
  if (!element) {
    element = attrs.rel ? document.createElement("link") : document.createElement("meta");
    document.head.appendChild(element);
  }
  Object.entries(attrs).forEach(([key, value]) => element!.setAttribute(key, value));
  return element;
}

export function useLocalizedMarketingSeo(locale: Locale) {
  useEffect(() => {
    const origin = window.location.origin;
    const path = locale === "vi" ? "/vi" : "/en";
    const canonical = `${origin}${path}`;
    const title =
      locale === "vi"
        ? "SaveStream — Tự động ghi livestream TikTok trên cloud"
        : "SaveStream — Automatic TikTok livestream recording in the cloud";
    const description =
      locale === "vi"
        ? "SaveStream tự động theo dõi kênh TikTok và ghi livestream trên cloud, kể cả khi máy tính của bạn đang tắt."
        : "SaveStream automatically monitors TikTok channels and records livestreams in the cloud, even when your computer is offline.";

    document.title = title;
    document.documentElement.lang = locale;

    ensureMeta('meta[name="description"]', { name: "description", content: description });
    ensureMeta('meta[property="og:title"]', { property: "og:title", content: title });
    ensureMeta('meta[property="og:description"]', { property: "og:description", content: description });
    ensureMeta('meta[property="og:type"]', { property: "og:type", content: "website" });
    ensureMeta('meta[property="og:url"]', { property: "og:url", content: canonical });
    ensureMeta('meta[property="og:locale"]', {
      property: "og:locale",
      content: locale === "vi" ? "vi_VN" : "en_US",
    });
    ensureMeta('meta[name="twitter:card"]', { name: "twitter:card", content: "summary_large_image" });
    ensureMeta('meta[name="twitter:title"]', { name: "twitter:title", content: title });
    ensureMeta('meta[name="twitter:description"]', { name: "twitter:description", content: description });

    ensureMeta('link[rel="canonical"]', { rel: "canonical", href: canonical });
    ensureMeta('link[rel="alternate"][hreflang="en"]', {
      rel: "alternate",
      hreflang: "en",
      href: `${origin}/en`,
    });
    ensureMeta('link[rel="alternate"][hreflang="vi"]', {
      rel: "alternate",
      hreflang: "vi",
      href: `${origin}/vi`,
    });
    ensureMeta('link[rel="alternate"][hreflang="x-default"]', {
      rel: "alternate",
      hreflang: "x-default",
      href: `${origin}/en`,
    });

    let schema = document.head.querySelector<HTMLScriptElement>('script[data-savestream-seo="marketing"]');
    if (!schema) {
      schema = document.createElement("script");
      schema.type = "application/ld+json";
      schema.dataset.savestreamSeo = "marketing";
      document.head.appendChild(schema);
    }
    schema.textContent = JSON.stringify({
      "@context": "https://schema.org",
      "@type": "SoftwareApplication",
      name: "SaveStream",
      applicationCategory: "MultimediaApplication",
      operatingSystem: "Web",
      url: canonical,
      description,
      inLanguage: locale === "vi" ? "vi-VN" : "en-US",
    });
  }, [locale]);
}

export function DouyinWaitlist() {
  const { locale } = usePreferences();
  const copy =
    locale === "vi"
      ? {
          title: "Nhận thông báo khi Douyin ra mắt",
          body: "Để lại email để lưu nhu cầu early access. Trong giai đoạn frontend, thông tin được lưu cục bộ trên thiết bị này.",
          placeholder: "ban@example.com",
          action: "Tham gia waitlist",
          success: "Đã lưu nhu cầu Douyin",
          successBody: "Email được lưu trên thiết bị này. Backend waitlist sẽ thay thế luồng này khi được triển khai.",
          invalid: "Nhập một email hợp lệ.",
        }
      : {
          title: "Get notified when Douyin launches",
          body: "Leave your email to save your early-access interest. During the frontend phase, this is stored locally on this device.",
          placeholder: "you@example.com",
          action: "Join waitlist",
          success: "Douyin interest saved",
          successBody: "Your email is saved on this device. A backend waitlist endpoint will replace this flow when implemented.",
          invalid: "Enter a valid email address.",
        };

  const stored = typeof window !== "undefined" ? window.localStorage.getItem("savestream.douyinWaitlistEmail") ?? "" : "";
  const [email, setEmail] = useState(stored);
  const [submitted, setSubmitted] = useState(Boolean(stored));
  const [error, setError] = useState("");

  const submit = () => {
    const value = email.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      setError(copy.invalid);
      return;
    }
    window.localStorage.setItem("savestream.douyinWaitlistEmail", value);
    setEmail(value);
    setError("");
    setSubmitted(true);
  };

  if (submitted) {
    return (
      <div className="mt-6 rounded-xl border border-emerald-200 bg-emerald-50 p-4 dark:border-emerald-500/20 dark:bg-emerald-500/10">
        <div className="flex items-start gap-3">
          <span className="grid size-8 shrink-0 place-items-center rounded-full bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300">
            <Check className="size-4" />
          </span>
          <div>
            <p className="text-sm font-semibold text-emerald-900 dark:text-emerald-200">{copy.success}</p>
            <p className="mt-1 text-xs leading-5 text-emerald-800/75 dark:text-emerald-200/70">{copy.successBody}</p>
            <button
              type="button"
              className="mt-2 text-xs font-semibold text-emerald-700 underline underline-offset-4 dark:text-emerald-300"
              onClick={() => setSubmitted(false)}
            >
              {email}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="mt-6 rounded-xl border border-[var(--border)] bg-[var(--subtle)] p-4">
      <p className="text-sm font-semibold">{copy.title}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--muted)]">{copy.body}</p>
      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <label className="flex h-10 min-w-0 flex-1 items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 focus-within:ring-2 focus-within:ring-indigo-400">
          <Mail className="size-4 shrink-0 text-[var(--muted)]" />
          <input
            type="email"
            value={email}
            onChange={(event) => {
              setEmail(event.target.value);
              setError("");
            }}
            placeholder={copy.placeholder}
            className="min-w-0 flex-1 bg-transparent text-sm outline-none"
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.preventDefault();
                submit();
              }
            }}
          />
        </label>
        <button
          type="button"
          onClick={submit}
          className="inline-flex h-10 shrink-0 items-center justify-center rounded-lg bg-amber-500 px-4 text-sm font-semibold text-slate-950 transition hover:bg-amber-400"
        >
          {copy.action}
        </button>
      </div>
      {error ? <p className="mt-2 text-xs font-medium text-red-600">{error}</p> : null}
    </div>
  );
}

export function PartnerArchiveProof() {
  const { locale } = usePreferences();
  const items = useMemo(() => sampleMedia.slice(0, 4), []);
  const copy =
    locale === "vi"
      ? {
          eyebrow: "Archive thực tế",
          title: "Một workflow được thiết kế quanh livestream dài và thư viện lớn.",
          body: "Các thumbnail dưới đây dùng chính recording sample đã được cung cấp cho SaveStream. Chúng minh họa loại nội dung dài mà partner archive đang lưu trữ và review.",
          noteTitle: "Tín hiệu từ partner",
          note: "Partner duy trì một kho lớn các livestream đã ghi. SaveStream đang được thiết kế để việc theo dõi, ghi, xem lại và tải xuống các phiên dài trở nên tự động hơn.",
          channel: "Mở kênh YouTube đối tác",
          sample: "Sample",
        }
      : {
          eyebrow: "Real archive proof",
          title: "A workflow designed around long livestreams and large recording libraries.",
          body: "These thumbnails use the recording samples provided to SaveStream and illustrate the kind of long-form content the partner archive stores and reviews.",
          noteTitle: "Partner signal",
          note: "The partner maintains a large archive of recorded livestreams. SaveStream is being designed to make monitoring, recording, review and download of long sessions more automatic.",
          channel: "Open partner YouTube channel",
          sample: "Sample",
        };

  return (
    <div className="grid gap-6 lg:grid-cols-[1.05fr_.95fr]">
      <div>
        <p className="text-sm font-semibold text-indigo-600">{copy.eyebrow}</p>
        <h3 className="mt-2 text-2xl font-semibold sm:text-3xl">{copy.title}</h3>
        <p className="mt-4 max-w-2xl text-sm leading-7 text-[var(--muted)]">{copy.body}</p>

        <div className="mt-6 rounded-2xl border border-[var(--border)] bg-[var(--subtle)] p-5 sm:p-6">
          <Quote className="size-6 text-indigo-500" />
          <p className="mt-4 text-sm font-semibold">{copy.noteTitle}</p>
          <p className="mt-2 text-sm leading-7 text-[var(--muted)]">{copy.note}</p>
          <p className="mt-4 text-xs text-[var(--muted)]">
            {locale === "vi"
              ? "Mô tả này là product copy, không phải lời chứng thực trực tiếp từ partner."
              : "This is product copy, not a direct partner testimonial."}
          </p>
        </div>

        <a
          href={PARTNER_CHANNEL}
          target="_blank"
          rel="noreferrer"
          className="mt-6 inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)]"
        >
          <Youtube className="size-4 text-red-600" /> {copy.channel}
        </a>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {items.map((item, index) => (
          <a
            key={item.id}
            href={PARTNER_CHANNEL}
            target="_blank"
            rel="noreferrer"
            className="group relative aspect-video overflow-hidden rounded-xl border border-[var(--border)] bg-slate-950"
          >
            <img
              src={item.thumbnailUrl}
              alt={`${copy.sample} ${index + 1}`}
              loading="lazy"
              className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
            />
            <span className="absolute inset-0 bg-gradient-to-t from-black/65 via-transparent to-transparent" />
            <span className="absolute bottom-2 left-2 inline-flex items-center gap-1.5 rounded-full bg-black/60 px-2 py-1 text-[10px] font-semibold text-white backdrop-blur">
              <Play className="size-3 fill-current" /> {copy.sample} {String(index + 1).padStart(2, "0")}
            </span>
          </a>
        ))}
      </div>
    </div>
  );
}
