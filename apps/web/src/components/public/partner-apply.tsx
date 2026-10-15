import { useRef, useState, type DragEvent, type FormEvent, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { Check, Clock, ImagePlus, MessageSquare, ShieldCheck, X } from "lucide-react";

import { authErrorMessage } from "@/api/auth";
import {
  PARTNER_CONSENT_DISPLAY,
  PARTNER_CONSENT_OWNS_ACCOUNT,
  PARTNER_NICHES,
  submitPartnerApplication,
  type PartnerApplicationReceipt,
} from "@/api/partners";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { TurnstileWidget } from "@/components/public/turnstile";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { PRIVACY_EMAIL, SUPPORT_RESPONSE_TIME } from "@/lib/support";
import { turnstileSiteKey } from "@/lib/turnstile";
import { cn } from "@/lib/utils";

const STORY_MAX = 600;
const STORY_MIN = 20;
const PHOTO_MAX_BYTES = 5 * 1024 * 1024;
const PHOTO_MIN_SIDE = 400;
const select =
  "h-11 w-full rounded-[12px] border bg-surface px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

type Photo = { dataUrl: string; name: string };

function Field({
  id,
  label,
  optional,
  hint,
  children,
}: {
  id: string;
  label: string;
  optional?: boolean;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-sm font-bold">
        {label}
        {optional ? <span className="font-medium text-muted-foreground"> (optional)</span> : " *"}
      </label>
      {children}
      {hint ? <span className="text-xs text-muted-foreground">{hint}</span> : null}
    </div>
  );
}

function Perk({
  icon,
  title,
  children,
  tone = "accent",
}: {
  icon: ReactNode;
  title: string;
  children: ReactNode;
  tone?: "accent" | "success";
}) {
  return (
    <li className="flex items-start gap-3">
      <span
        className={cn(
          "grid size-9 shrink-0 place-items-center rounded-[10px]",
          tone === "success"
            ? "bg-success-subtle text-success"
            : "bg-primary-subtle text-accent-ink",
        )}
      >
        {icon}
      </span>
      <span className="flex flex-col gap-0.5">
        <b>{title}</b>
        <span className="text-sm text-muted-foreground">{children}</span>
      </span>
    </li>
  );
}

function readPhoto(file: File): Promise<Photo> {
  return new Promise((resolve, reject) => {
    if (!["image/png", "image/jpeg"].includes(file.type)) {
      reject(new Error("Use a PNG or JPG image."));
      return;
    }
    if (file.size > PHOTO_MAX_BYTES) {
      reject(new Error("The image must be 5 MB or smaller."));
      return;
    }
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("The image could not be read."));
    reader.onload = () => {
      const dataUrl = String(reader.result);
      const image = new Image();
      image.onerror = () => reject(new Error("The image could not be read."));
      image.onload = () => {
        if (image.naturalWidth < PHOTO_MIN_SIDE || image.naturalHeight < PHOTO_MIN_SIDE) {
          reject(new Error(`The image must be at least ${PHOTO_MIN_SIDE} × ${PHOTO_MIN_SIDE} px.`));
          return;
        }
        resolve({ dataUrl, name: file.name });
      };
      image.src = dataUrl;
    };
    reader.readAsDataURL(file);
  });
}

function PhotoPicker({
  photo,
  onPhoto,
}: {
  photo: Photo | null;
  onPhoto: (photo: Photo | null) => void;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const take = (file: File | undefined) => {
    if (!file) return;
    setError(null);
    readPhoto(file).then(onPhoto, (reason: Error) => setError(reason.message));
  };
  const drop = (event: DragEvent) => {
    event.preventDefault();
    setDragging(false);
    take(event.dataTransfer.files[0]);
  };

  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-sm font-bold">
        Logo or photo <span className="font-medium text-muted-foreground">(optional)</span>
      </span>
      {photo ? (
        <div className="flex items-center gap-3 rounded-[14px] border bg-surface-2 p-3">
          <img src={photo.dataUrl} alt="" className="size-14 rounded-[10px] object-cover" />
          <span className="min-w-0 flex-1 truncate text-sm font-semibold">{photo.name}</span>
          <Button type="button" variant="ghost" size="sm" onClick={() => onPhoto(null)}>
            <X className="size-4" />
            Remove
          </Button>
        </div>
      ) : (
        <div
          onDragOver={(event) => {
            event.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={drop}
          className={cn(
            "flex flex-col items-center gap-1.5 rounded-[14px] border-2 border-dashed px-4 py-6 text-center text-sm",
            dragging ? "border-primary bg-primary-subtle" : "bg-surface-2/50",
          )}
        >
          <ImagePlus className="size-6 text-muted-foreground" />
          <span>
            Drop an image or{" "}
            <button
              type="button"
              className="font-semibold text-accent-ink hover:underline"
              onClick={() => input.current?.click()}
            >
              browse
            </button>
          </span>
          <span className="text-xs text-muted-foreground">
            PNG or JPG, up to 5 MB, at least {PHOTO_MIN_SIDE} × {PHOTO_MIN_SIDE} px
          </span>
          <input
            ref={input}
            type="file"
            accept="image/png,image/jpeg"
            className="sr-only"
            aria-label="Logo or photo"
            onChange={(event) => {
              take(event.target.files?.[0]);
              event.target.value = "";
            }}
          />
        </div>
      )}
      {error ? (
        <span role="alert" className="text-xs font-semibold text-destructive">
          {error}
        </span>
      ) : null}
    </div>
  );
}

function Received({ result, onEdit }: { result: PartnerApplicationReceipt; onEdit: () => void }) {
  return (
    <div className="flex flex-col items-center gap-4 px-2 py-6 text-center" role="status">
      <span className="grid size-16 place-items-center rounded-[20px] bg-success-subtle text-success">
        <Check className="size-8" />
      </span>
      <h2 className="text-[26px] font-extrabold tracking-[-.025em]">Application received</h2>
      <p className="max-w-[440px] text-muted-foreground">
        Thanks for applying. We’ll review your channel and email you within {SUPPORT_RESPONSE_TIME}.
        You’ll approve the final quote, image and clip before anything is published.
      </p>
      <p className="text-sm text-muted-foreground">
        Reference <b className="font-mono text-foreground">{result.reference}</b>
      </p>
      <div className="w-full max-w-[400px] rounded-[16px] bg-surface-2 p-5 text-left">
        <p className="mb-3 text-xs font-bold uppercase tracking-[.08em] text-muted-foreground">
          What happens next
        </p>
        <ol className="flex flex-col gap-2.5 text-sm">
          {[
            "We confirm you own the channel",
            "We draft your story and send it for approval",
            "50 free recording hours are added when it goes live",
          ].map((step, index) => (
            <li key={step} className="flex items-center gap-2.5">
              <span className="grid size-6 shrink-0 place-items-center rounded-full bg-primary-subtle font-mono text-xs font-bold text-accent-ink">
                {index + 1}
              </span>
              {step}
            </li>
          ))}
        </ol>
      </div>
      <div className="flex flex-wrap justify-center gap-2">
        <Button variant="outline" asChild>
          <Link to="/">Back to home</Link>
        </Button>
        <Button variant="ghost" onClick={onEdit}>
          Edit application
        </Button>
      </div>
    </div>
  );
}

export function PartnerApplyPage() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [handle, setHandle] = useState("");
  const [otherUrl, setOtherUrl] = useState("");
  const [niche, setNiche] = useState("");
  const [story, setStory] = useState("");
  const [photo, setPhoto] = useState<Photo | null>(null);
  const [ownsAccount, setOwnsAccount] = useState(false);
  const [consent, setConsent] = useState(false);
  const [website, setWebsite] = useState("");
  const [token, setToken] = useState<string | null>(null);
  const [resetKey, setResetKey] = useState(0);
  const [tried, setTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<PartnerApplicationReceipt | null>(null);

  const cleanHandle = handle.trim().replace(/^@/, "");
  const ready =
    name.trim() &&
    email.includes("@") &&
    /^[A-Za-z0-9._]{2,24}$/.test(cleanHandle) &&
    niche &&
    story.trim().length >= STORY_MIN &&
    ownsAccount &&
    consent;
  const needsToken = Boolean(turnstileSiteKey) && !token;

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setTried(true);
    if (!ready || needsToken) return;
    setBusy(true);
    setError(null);
    try {
      setResult(
        await submitPartnerApplication({
          name,
          email,
          tiktok_handle: cleanHandle,
          other_channel_url: otherUrl.trim() || null,
          niche,
          story,
          photo: photo?.dataUrl ?? null,
          consent_owns_account: ownsAccount,
          consent_display: consent,
          turnstile_token: token,
          website,
        }),
      );
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (requestError) {
      setError(authErrorMessage(requestError));
      // A Turnstile token is single-use: ask for a fresh challenge.
      setResetKey((key) => key + 1);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="relative pt-[72px]">
        <div aria-hidden className="hero-glow" />
        <div className="relative mx-auto flex max-w-[1140px] flex-wrap items-start gap-14 px-6 pt-16">
          <div className="flex max-w-[460px] flex-[1_1_340px] flex-col gap-5 lg:sticky lg:top-[104px]">
            <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              Partner Program
            </span>
            <h1 className="text-[40px] font-extrabold leading-[1.05] tracking-[-.035em] sm:text-[46px]">
              Share your story. Get free recording hours.
            </h1>
            <p className="text-[17px] leading-relaxed text-muted-foreground">
              If SaveStream records your own TikTok LIVEs, we’d love to feature you on our site.
            </p>
            <ul className="mt-2 flex flex-col gap-3.5">
              <Perk icon={<Clock className="size-[18px]" />} title="50 free recording hours">
                Added to your balance when your story goes live.
              </Perk>
              <Perk icon={<MessageSquare className="size-[18px]" />} title="You approve everything">
                We send the final quote, image and clip for your sign-off before publishing.
              </Perk>
              <Perk
                tone="success"
                icon={<ShieldCheck className="size-[18px]" />}
                title="Remove it any time"
              >
                Email{" "}
                <a className="font-semibold text-accent-ink" href={`mailto:${PRIVACY_EMAIL}`}>
                  {PRIVACY_EMAIL}
                </a>{" "}
                and we take your story down.
              </Perk>
            </ul>
          </div>

          <section
            className="flex min-w-0 flex-[999_1_520px] flex-col gap-5 rounded-[22px] border bg-surface p-6 shadow-card sm:p-8"
            aria-label="Partner application"
          >
            {result ? (
              <Received result={result} onEdit={() => setResult(null)} />
            ) : (
              <form
                className="flex flex-col gap-[18px]"
                aria-label="Apply as a partner"
                onSubmit={(event) => void submit(event)}
                noValidate
              >
                <div className="flex flex-col gap-1">
                  <h2 className="text-[22px] font-extrabold tracking-[-.02em]">
                    Apply as a partner
                  </h2>
                  <span className="text-sm text-muted-foreground">
                    Takes about 3 minutes. Fields marked * are required.
                  </span>
                </div>
                {error ? (
                  <p
                    role="alert"
                    className="rounded-[12px] border border-destructive/30 bg-recording-subtle px-4 py-3 text-sm text-destructive"
                  >
                    {error}
                  </p>
                ) : null}
                {/* Honeypot: hidden from people and screen readers; bots fill it in. */}
                <div
                  aria-hidden="true"
                  className="absolute -left-[9999px] h-px w-px overflow-hidden"
                >
                  <label>
                    Website
                    <input
                      tabIndex={-1}
                      autoComplete="off"
                      value={website}
                      onChange={(e) => setWebsite(e.target.value)}
                    />
                  </label>
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field id="pa-name" label="Name">
                    <Input
                      id="pa-name"
                      autoComplete="name"
                      placeholder="Your name or creator name"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                    />
                  </Field>
                  <Field id="pa-email" label="Email">
                    <Input
                      id="pa-email"
                      type="email"
                      autoComplete="email"
                      placeholder="you@example.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                    />
                  </Field>
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field
                    id="pa-handle"
                    label="TikTok handle"
                    hint="Must be your own channel — the one you record with SaveStream."
                  >
                    <div className="flex h-11 items-center rounded-[12px] border bg-surface focus-within:ring-2 focus-within:ring-ring">
                      <span className="pl-3 font-mono text-sm text-muted-foreground">@</span>
                      <input
                        id="pa-handle"
                        className="h-full min-w-0 flex-1 bg-transparent px-1.5 text-sm outline-none"
                        placeholder="yourhandle"
                        autoCapitalize="off"
                        spellCheck={false}
                        value={handle}
                        onChange={(e) => setHandle(e.target.value)}
                      />
                    </div>
                  </Field>
                  <Field id="pa-other" label="YouTube or other channel" optional>
                    <Input
                      id="pa-other"
                      type="url"
                      placeholder="https://"
                      value={otherUrl}
                      onChange={(e) => setOtherUrl(e.target.value)}
                    />
                  </Field>
                </div>
                <Field id="pa-niche" label="Niche">
                  <select
                    id="pa-niche"
                    className={select}
                    value={niche}
                    onChange={(e) => setNiche(e.target.value)}
                  >
                    <option value="">Choose one</option>
                    {PARTNER_NICHES.map((item) => (
                      <option key={item}>{item}</option>
                    ))}
                  </select>
                </Field>
                <Field
                  id="pa-story"
                  label="Your story"
                  hint={
                    <span className="flex justify-between gap-3">
                      <span>How do you use SaveStream? What changed for you?</span>
                      <span className="font-mono">
                        {story.length} / {STORY_MAX}
                      </span>
                    </span>
                  }
                >
                  <Textarea
                    id="pa-story"
                    className="min-h-[120px]"
                    maxLength={STORY_MAX}
                    value={story}
                    onChange={(e) => setStory(e.target.value)}
                  />
                </Field>
                <PhotoPicker photo={photo} onPhoto={setPhoto} />

                <fieldset className="flex flex-col gap-3 rounded-[14px] bg-surface-2 p-4 text-sm">
                  <legend className="float-left mb-1 text-xs font-bold uppercase tracking-[.08em] text-muted-foreground">
                    Required confirmations
                  </legend>
                  <label className="clear-left flex items-start gap-2.5">
                    <input
                      type="checkbox"
                      className="mt-0.5 size-4 accent-[var(--primary)]"
                      checked={ownsAccount}
                      onChange={(e) => setOwnsAccount(e.target.checked)}
                    />
                    <span>{PARTNER_CONSENT_OWNS_ACCOUNT} *</span>
                  </label>
                  {tried && !ownsAccount ? (
                    <span className="-mt-1.5 pl-6 text-xs font-semibold text-destructive">
                      Please confirm you own or manage this account.
                    </span>
                  ) : null}
                  <label className="flex items-start gap-2.5">
                    <input
                      type="checkbox"
                      className="mt-0.5 size-4 accent-[var(--primary)]"
                      checked={consent}
                      onChange={(e) => setConsent(e.target.checked)}
                    />
                    <span>
                      {PARTNER_CONSENT_DISPLAY} *{" "}
                      <Link
                        to="/privacy"
                        hash="section-10"
                        className="font-semibold text-accent-ink hover:underline"
                      >
                        Privacy Policy §10
                      </Link>
                    </span>
                  </label>
                  {tried && !consent ? (
                    <span className="-mt-1.5 pl-6 text-xs font-semibold text-destructive">
                      Consent is required to feature your story.
                    </span>
                  ) : null}
                </fieldset>

                <TurnstileWidget onToken={setToken} resetKey={resetKey} />
                {tried && !ready ? (
                  <p className="text-sm font-semibold text-destructive">
                    Fill in the required fields
                    {story.trim().length < STORY_MIN
                      ? ` (story: at least ${STORY_MIN} characters)`
                      : ""}{" "}
                    and both confirmations.
                  </p>
                ) : null}
                <Button type="submit" size="lg" disabled={busy}>
                  {busy ? "Sending…" : "Submit application"}
                </Button>
                <p className="text-xs text-muted-foreground">
                  We reply within {SUPPORT_RESPONSE_TIME}. Nothing is published until you approve
                  the final version. How we handle your data:{" "}
                  <Link
                    to="/privacy"
                    hash="section-10"
                    className="font-semibold text-accent-ink hover:underline"
                  >
                    Privacy Policy
                  </Link>
                  .
                </p>
              </form>
            )}
          </section>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
