import {
  Check,
  ChevronDown,
  Globe2,
  Monitor,
  Moon,
  Sun,
  type LucideIcon,
} from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  usePreferences,
  type Locale,
  type ThemePreference,
} from "../lib/preferences";

export function PreferencesControls({
  compact = false,
  onLocaleChange,
}: {
  compact?: boolean;
  onLocaleChange?: (locale: Locale) => void;
}) {
  const { locale, setLocale, theme, setTheme, t } = usePreferences();

  const changeLocale = (nextLocale: Locale) => {
    setLocale(nextLocale);
    onLocaleChange?.(nextLocale);
  };

  const languageOptions: Array<{
    value: Locale;
    label: string;
    compactLabel: string;
  }> = [
    { value: "en", label: t("preferences.english"), compactLabel: "EN" },
    { value: "vi", label: t("preferences.vietnamese"), compactLabel: "VI" },
  ];

  const themeOptions: Array<{
    value: ThemePreference;
    label: string;
    compactLabel: string;
    icon: LucideIcon;
  }> = [
    {
      value: "system",
      label: t("theme.system"),
      compactLabel: "Auto",
      icon: Monitor,
    },
    {
      value: "light",
      label: t("theme.light"),
      compactLabel: t("theme.light"),
      icon: Sun,
    },
    {
      value: "dark",
      label: t("theme.dark"),
      compactLabel: t("theme.dark"),
      icon: Moon,
    },
  ];

  const selectedLanguage = languageOptions.find((option) => option.value === locale)!;
  const selectedTheme = themeOptions.find((option) => option.value === theme)!;

  return (
    <div
      className="flex items-center gap-2"
      aria-label={`${t("preferences.language")} / ${t("preferences.theme")}`}
    >
      <PreferenceMenu
        value={locale}
        onChange={changeLocale}
        ariaLabel={t("preferences.language")}
        triggerWidth={compact ? "min-w-[5.6rem]" : "min-w-[9.5rem]"}
        trigger={
          <>
            <Globe2 className="size-4 shrink-0 text-[var(--muted)]" />
            <span className="whitespace-nowrap">
              {compact ? selectedLanguage.compactLabel : selectedLanguage.label}
            </span>
          </>
        }
        options={languageOptions.map((option) => ({
          value: option.value,
          label: option.label,
          icon: Globe2,
        }))}
      />

      <PreferenceMenu
        value={theme}
        onChange={setTheme}
        ariaLabel={t("preferences.theme")}
        triggerWidth={compact ? "min-w-[7.1rem]" : "min-w-[10rem]"}
        trigger={
          <>
            <ThemeIcon theme={theme} />
            <span className="whitespace-nowrap">
              {compact ? selectedTheme.compactLabel : selectedTheme.label}
            </span>
          </>
        }
        options={themeOptions}
      />
    </div>
  );
}

function PreferenceMenu<T extends string>({
  value,
  onChange,
  ariaLabel,
  trigger,
  triggerWidth,
  options,
}: {
  value: T;
  onChange: (value: T) => void;
  ariaLabel: string;
  trigger: ReactNode;
  triggerWidth: string;
  options: Array<{ value: T; label: string; icon: LucideIcon }>;
}) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;

    const closeOnOutsideClick = (event: PointerEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };

    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };

    document.addEventListener("pointerdown", closeOnOutsideClick);
    document.addEventListener("keydown", closeOnEscape);

    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((current) => !current)}
        aria-label={ariaLabel}
        aria-haspopup="listbox"
        aria-expanded={open}
        className={`flex h-10 ${triggerWidth} shrink-0 items-center gap-2 rounded-full border border-[var(--border)] bg-[var(--surface)] px-3.5 text-xs font-medium text-[var(--fg)] shadow-sm outline-none transition hover:bg-[var(--subtle)] focus-visible:border-indigo-400 focus-visible:ring-2 focus-visible:ring-indigo-400/30`}
      >
        {trigger}
        <ChevronDown
          className={`ml-auto size-3.5 shrink-0 text-[var(--muted)] transition-transform ${open ? "rotate-180" : ""}`}
        />
      </button>

      {open ? (
        <div
          role="listbox"
          aria-label={ariaLabel}
          className="absolute right-0 z-50 mt-2 min-w-[12rem] overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-1.5 shadow-xl shadow-black/10 dark:shadow-black/30"
        >
          {options.map((option) => {
            const Icon = option.icon;
            const selected = option.value === value;

            return (
              <button
                key={option.value}
                type="button"
                role="option"
                aria-selected={selected}
                onClick={() => {
                  onChange(option.value);
                  setOpen(false);
                }}
                className={`flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-sm outline-none transition hover:bg-[var(--subtle)] focus-visible:bg-[var(--subtle)] ${selected ? "font-medium text-indigo-600 dark:text-indigo-300" : "text-[var(--fg)]"}`}
              >
                <Icon className="size-4 shrink-0 text-[var(--muted)]" />
                <span className="whitespace-nowrap">{option.label}</span>
                {selected ? <Check className="ml-auto size-4 shrink-0" /> : null}
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

function ThemeIcon({ theme }: { theme: ThemePreference }) {
  const className = "size-4 shrink-0 text-[var(--muted)]";
  if (theme === "light") return <Sun className={className} />;
  if (theme === "dark") return <Moon className={className} />;
  return <Monitor className={className} />;
}
