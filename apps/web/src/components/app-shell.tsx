import { Link, useRouterState } from "@tanstack/react-router";
import { Bell, CircleHelp, Gauge, LayoutDashboard, Menu, Radio, Settings, Video, X } from "lucide-react";
import { useState, type ReactNode } from "react";
import { user } from "../lib/mock-data";
import { usePreferences } from "../lib/preferences";
import { Logo } from "./brand";
import { PreferencesControls } from "./preferences-controls";

const nav = [
  ["/overview", "nav.overview", LayoutDashboard],
  ["/channels", "nav.channels", Radio],
  ["/recordings", "nav.recordings", Video],
  ["/usage", "nav.usage", Gauge],
] as const;

export function AppShell({ children }: { children: ReactNode }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const { locale, t } = usePreferences();
  const pathname = useRouterState({ select: (state) => state.location.pathname });

  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--fg)]">
      <div
        className={`fixed inset-0 z-40 bg-black/40 backdrop-blur-[1px] lg:hidden ${menuOpen ? "block" : "hidden"}`}
        onClick={() => setMenuOpen(false)}
      />
      <aside className={`fixed inset-y-0 left-0 z-50 flex w-[min(18rem,86vw)] flex-col border-r border-[var(--border)] bg-[var(--surface)] shadow-2xl transition-transform lg:w-64 lg:translate-x-0 lg:shadow-none ${menuOpen ? "translate-x-0" : "-translate-x-full"}`}>
        <div className="flex h-16 items-center justify-between px-4 sm:px-5">
          <Logo />
          <button className="icon-button lg:hidden" onClick={() => setMenuOpen(false)} aria-label={t("nav.closeMenu")}>
            <X className="size-4" />
          </button>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-3">
          {nav.map(([to, labelKey, Icon]) => {
            const active = pathname === to || pathname.startsWith(`${to}/`) || (to === "/usage" && pathname.startsWith("/billing"));
            return (
              <Link key={to} to={to} onClick={() => setMenuOpen(false)} className={`flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition ${active ? "bg-indigo-50 text-indigo-700 dark:bg-indigo-500/10 dark:text-indigo-300" : "text-[var(--muted)] hover:bg-[var(--subtle)] hover:text-[var(--fg)]"}`}>
                <Icon className="size-4" />{t(labelKey)}
              </Link>
            );
          })}
          <div className="my-4 border-t border-[var(--border)]" />
          <Link to="/notifications" onClick={() => setMenuOpen(false)} className="sidebar-link"><Bell className="size-4" />{t("nav.notifications")}</Link>
          <Link to="/settings" onClick={() => setMenuOpen(false)} className="sidebar-link"><Settings className="size-4" />{t("nav.settings")}</Link>
          <Link to="/help" onClick={() => setMenuOpen(false)} className="sidebar-link"><CircleHelp className="size-4" />{t("nav.help")}</Link>
        </nav>
        <div className="border-t border-[var(--border)] p-3">
          <div className="mb-2 px-2"><PreferencesControls /></div>
          <Link to="/settings" onClick={() => setMenuOpen(false)} className="flex items-center gap-3 rounded-lg p-2 hover:bg-[var(--subtle)]">
            <span className="grid size-9 place-items-center rounded-full bg-indigo-600 text-xs font-semibold text-white">{user.initials}</span>
            <span className="min-w-0"><b className="block truncate text-sm font-medium">{user.name}</b><small className="text-[var(--muted)]">{user.plan} {t("nav.plan")}</small></span>
          </Link>
        </div>
      </aside>
      <div className="lg:pl-64">
        <header className="sticky top-0 z-30 flex h-14 items-center border-b border-[var(--border)] bg-[color:var(--bg)]/95 px-3 backdrop-blur sm:h-16 sm:px-4 lg:px-6">
          <button className="icon-button lg:hidden" onClick={() => setMenuOpen(true)} aria-label={t("nav.openMenu")}><Menu className="size-4" /></button>
          <div className="ml-2 lg:hidden"><Logo compact /></div>
          <div className="ml-auto hidden sm:block"><PreferencesControls compact /></div>
          <Link to="/notifications" className="relative ml-1 icon-button" aria-label={t("nav.notifications")}><Bell className="size-4" /><span className="absolute right-1 top-1 size-2 rounded-full bg-red-500" /></Link>
          <span className="ml-1.5 grid size-8 place-items-center rounded-full bg-indigo-600 text-[11px] font-semibold text-white sm:ml-2">{user.initials}</span>
        </header>
        <main className="mx-auto max-w-[1720px] px-3 pb-28 pt-4 sm:px-5 sm:pt-6 lg:px-6 lg:pb-10 lg:pt-8 xl:px-8 2xl:px-10">{children}</main>
      </div>
      <nav aria-label="Primary navigation" className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-4 border-t border-[var(--border)] bg-[color:var(--surface)]/95 px-1 pb-[max(.25rem,env(safe-area-inset-bottom))] pt-1 backdrop-blur lg:hidden">
        {nav.map(([to, labelKey, Icon]) => {
          const active = pathname === to || pathname.startsWith(`${to}/`) || (to === "/usage" && pathname.startsWith("/billing"));
          const mobileLabel = labelKey === "nav.usage" ? (locale === "vi" ? "Sử dụng" : "Usage") : t(labelKey);
          return (
            <Link key={to} to={to} className={`flex min-h-14 flex-col items-center justify-center gap-1 rounded-lg px-1 text-[10px] font-medium transition ${active ? "text-indigo-600" : "text-[var(--muted)]"}`}>
              <Icon className="size-4" />
              <span className="truncate">{mobileLabel}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
