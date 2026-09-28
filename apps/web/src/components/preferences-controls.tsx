import { Globe2, Monitor, Moon, Sun } from "lucide-react";
import { usePreferences, type ThemePreference } from "../lib/preferences";

export function PreferencesControls({ compact = false }: { compact?: boolean }) {
  const { locale, setLocale, theme, setTheme, t } = usePreferences();

  return (
    <div className="flex items-center gap-1.5" aria-label={`${t("preferences.language")} / ${t("preferences.theme")}`}>
      <label className="relative inline-flex items-center">
        <Globe2 className="pointer-events-none absolute left-2.5 size-4 text-[var(--muted)]" />
        <span className="sr-only">{t("preferences.language")}</span>
        <select
          value={locale}
          onChange={(event) => setLocale(event.target.value as "en" | "vi")}
          className={`h-9 appearance-none rounded-lg border border-[var(--border)] bg-[var(--surface)] pl-8 pr-3 text-xs font-medium text-[var(--fg)] outline-none transition hover:bg-[var(--subtle)] focus:border-indigo-400 focus:ring-2 focus:ring-indigo-400/30 ${compact ? "w-[4.4rem]" : "w-[7.7rem]"}`}
          aria-label={t("preferences.language")}
          title={t("preferences.language")}
        >
          <option value="en">{compact ? "EN" : t("preferences.english")}</option>
          <option value="vi">{compact ? "VI" : t("preferences.vietnamese")}</option>
        </select>
      </label>

      <label className="relative inline-flex items-center">
        <ThemeIcon theme={theme} />
        <span className="sr-only">{t("preferences.theme")}</span>
        <select
          value={theme}
          onChange={(event) => setTheme(event.target.value as ThemePreference)}
          className={`h-9 appearance-none rounded-lg border border-[var(--border)] bg-[var(--surface)] pl-8 pr-3 text-xs font-medium text-[var(--fg)] outline-none transition hover:bg-[var(--subtle)] focus:border-indigo-400 focus:ring-2 focus:ring-indigo-400/30 ${compact ? "w-[5.4rem]" : "w-[8.2rem]"}`}
          aria-label={t("preferences.theme")}
          title={t("preferences.theme")}
        >
          <option value="system">{compact ? (locale === "vi" ? "Auto" : "Auto") : t("theme.system")}</option>
          <option value="light">{t("theme.light")}</option>
          <option value="dark">{t("theme.dark")}</option>
        </select>
      </label>
    </div>
  );
}

function ThemeIcon({ theme }: { theme: ThemePreference }) {
  const className = "pointer-events-none absolute left-2.5 size-4 text-[var(--muted)]";
  if (theme === "light") return <Sun className={className} />;
  if (theme === "dark") return <Moon className={className} />;
  return <Monitor className={className} />;
}
