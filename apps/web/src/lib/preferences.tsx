import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type Language = "en";
export type ThemePreference = "light" | "dark" | "system";

const THEME_STORAGE_KEY = "savestream:ui:theme";
const LEGACY_THEME_STORAGE_KEY = "savestream-theme";

function readUiPreference(primaryKey: string, legacyKey: string) {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(primaryKey) ?? window.localStorage.getItem(legacyKey);
  } catch {
    return null;
  }
}

function writeUiPreference(primaryKey: string, legacyKey: string, value: string) {
  try {
    window.localStorage.setItem(primaryKey, value);
    window.localStorage.removeItem(legacyKey);
  } catch {
    // UI preferences are best-effort and must never block application state.
  }
}

type Preferences = {
  language: Language;
  theme: ThemePreference;
  setTheme: (theme: ThemePreference) => void;
  t: (text: string) => string;
};

const Context = createContext<Preferences | null>(null);

function applyTheme(theme: ThemePreference) {
  const dark =
    theme === "dark" ||
    (theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.classList.toggle("dark", dark);
  document.documentElement.dataset["theme"] = theme;
  document.documentElement.style.colorScheme = dark ? "dark" : "light";
}

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<ThemePreference>("system");
  useEffect(() => {
    const savedTheme = readUiPreference(THEME_STORAGE_KEY, LEGACY_THEME_STORAGE_KEY);
    const nextTheme: ThemePreference =
      savedTheme === "light" || savedTheme === "dark" || savedTheme === "system"
        ? savedTheme
        : "system";
    setThemeState(nextTheme);
    applyTheme(nextTheme);
  }, []);
  useEffect(() => {
    applyTheme(theme);
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const update = () => theme === "system" && applyTheme("system");
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, [theme]);
  const t = useCallback((text: string) => text, []);
  const value = useMemo<Preferences>(
    () => ({
      language: "en",
      theme,
      setTheme: (next) => {
        writeUiPreference(THEME_STORAGE_KEY, LEGACY_THEME_STORAGE_KEY, next);
        setThemeState(next);
      },
      t,
    }),
    [theme, t],
  );
  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function usePreferences() {
  const value = useContext(Context);
  if (!value) throw new Error("usePreferences must be used inside PreferencesProvider");
  return value;
}

export const themeInitScript = `(function(){try{var t=localStorage.getItem('savestream:ui:theme')||localStorage.getItem('savestream-theme')||'system';var d=t==='dark'||(t==='system'&&matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);document.documentElement.dataset.theme=t;document.documentElement.style.colorScheme=d?'dark':'light'}catch(e){}})()`;
export const languageInitScript = `(function(){try{document.documentElement.lang='en';document.documentElement.dataset.language='en'}catch(e){}})()`;
