import { Link, useRouterState } from "@tanstack/react-router";
import { Bell, CircleHelp, Gauge, LayoutDashboard, Menu, Moon, Radio, Settings, Sun, Video, X } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";
import { user } from "../lib/mock-data";
import { Logo } from "./brand";

const nav = [
  ["/overview", "Overview", LayoutDashboard],
  ["/channels", "Channels", Radio],
  ["/recordings", "Recordings", Video],
  ["/usage", "Usage", Gauge],
] as const;

export function AppShell({ children }: { children: ReactNode }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [dark, setDark] = useState(false);
  const pathname = useRouterState({ select: (state) => state.location.pathname });

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
  }, [dark]);

  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--fg)]">
      <div
        className={`fixed inset-0 z-40 bg-black/40 backdrop-blur-[1px] lg:hidden ${menuOpen ? "block" : "hidden"}`}
        onClick={() => setMenuOpen(false)}
      />
      <aside className={`fixed inset-y-0 left-0 z-50 flex w-[min(18rem,86vw)] flex-col border-r border-[var(--border)] bg-[var(--surface)] shadow-2xl transition-transform lg:w-64 lg:translate-x-0 lg:shadow-none ${menuOpen ? "translate-x-0" : "-translate-x-full"}`}>
        <div className="flex h-16 items-center justify-between px-4 sm:px-5">
          <Logo />
          <button className="icon-button lg:hidden" onClick={() => setMenuOpen(false)} aria-label="Close menu"><X className="size-4" /></button>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-3">
          {nav.map(([to, label, Icon]) => {
            const active = pathname === to || pathname.startsWith(`${to}/`) || (to === "/usage" && pathname.startsWith("/billing"));
            return (
              <Link key={to} to={to} onClick={() => setMenuOpen(false)} className={`flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition ${active ? "bg-indigo-50 text-indigo-700 dark:bg-indigo-500/10 dark:text-indigo-300" : "text-[var(--muted)] hover:bg-[var(--subtle)] hover:text-[var(--fg)]"}`}>
                <Icon className="size-4" />{label === "Usage" ? "Usage & Billing" : label}
              </Link>
            );
          })}
          <div className="my-4 border-t border-[var(--border)]" />
          <Link to="/notifications" onClick={() => setMenuOpen(false)} className="sidebar-link"><Bell className="size-4" />Notifications</Link>
          <Link to="/settings" onClick={() => setMenuOpen(false)} className="sidebar-link"><Settings className="size-4" />Settings</Link>
          <Link to="/help" onClick={() => setMenuOpen(false)} className="sidebar-link"><CircleHelp className="size-4" />Help</Link>
        </nav>
        <div className="border-t border-[var(--border)] p-3">
          <Link to="/settings" onClick={() => setMenuOpen(false)} className="flex items-center gap-3 rounded-lg p-2 hover:bg-[var(--subtle)]">
            <span className="grid size-9 place-items-center rounded-full bg-indigo-600 text-xs font-semibold text-white">{user.initials}</span>
            <span className="min-w-0"><b className="block truncate text-sm font-medium">{user.name}</b><small className="text-[var(--muted)]">{user.plan} plan</small></span>
          </Link>
        </div>
      </aside>
      <div className="lg:pl-64">
        <header className="sticky top-0 z-30 flex h-14 items-center border-b border-[var(--border)] bg-[color:var(--bg)]/95 px-3 backdrop-blur sm:h-16 sm:px-4 lg:px-6">
          <button className="icon-button lg:hidden" onClick={() => setMenuOpen(true)} aria-label="Open menu"><Menu className="size-4" /></button>
          <div className="ml-2 lg:hidden"><Logo compact /></div>
          <button className="ml-auto icon-button" onClick={() => setDark((value) => !value)} aria-label="Toggle theme">{dark ? <Sun className="size-4" /> : <Moon className="size-4" />}</button>
          <Link to="/notifications" className="relative ml-1 icon-button" aria-label="Notifications"><Bell className="size-4" /><span className="absolute right-1 top-1 size-2 rounded-full bg-red-500" /></Link>
          <span className="ml-1.5 grid size-8 place-items-center rounded-full bg-indigo-600 text-[11px] font-semibold text-white sm:ml-2">{user.initials}</span>
        </header>
        <main className="mx-auto max-w-[1320px] px-3 pb-28 pt-4 sm:px-5 sm:pt-6 lg:px-8 lg:pb-10 lg:pt-8">{children}</main>
      </div>
      <nav aria-label="Primary navigation" className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-4 border-t border-[var(--border)] bg-[color:var(--surface)]/95 px-1 pb-[max(.25rem,env(safe-area-inset-bottom))] pt-1 backdrop-blur lg:hidden">
        {nav.map(([to, label, Icon]) => {
          const active = pathname === to || pathname.startsWith(`${to}/`) || (to === "/usage" && pathname.startsWith("/billing"));
          return (
            <Link key={to} to={to} className={`flex min-h-14 flex-col items-center justify-center gap-1 rounded-lg px-1 text-[10px] font-medium transition ${active ? "text-indigo-600" : "text-[var(--muted)]"}`}>
              <Icon className="size-4" />
              <span className="truncate">{label}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
