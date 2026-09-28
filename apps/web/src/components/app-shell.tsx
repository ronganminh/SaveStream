import { Link, useRouterState } from "@tanstack/react-router";
import { Bell, CircleHelp, Gauge, LayoutDashboard, Menu, Moon, Radio, Settings, Sun, Video, X } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";
import { user } from "../lib/mock-data";
import { Logo } from "./brand";

const nav = [
  ["/overview", "Overview", LayoutDashboard],
  ["/channels", "Channels", Radio],
  ["/recordings", "Recordings", Video],
  ["/usage", "Usage & Billing", Gauge],
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
        className={`fixed inset-0 z-40 bg-black/40 lg:hidden ${menuOpen ? "block" : "hidden"}`}
        onClick={() => setMenuOpen(false)}
      />
      <aside className={`fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-[var(--border)] bg-[var(--surface)] transition-transform lg:translate-x-0 ${menuOpen ? "translate-x-0" : "-translate-x-full"}`}>
        <div className="flex h-16 items-center justify-between px-5">
          <Logo />
          <button className="icon-button lg:hidden" onClick={() => setMenuOpen(false)} aria-label="Close menu"><X className="size-4" /></button>
        </div>
        <nav className="flex-1 space-y-1 px-3 py-3">
          {nav.map(([to, label, Icon]) => {
            const active = pathname === to || pathname.startsWith(`${to}/`) || (to === "/usage" && pathname.startsWith("/billing"));
            return (
              <Link key={to} to={to} onClick={() => setMenuOpen(false)} className={`flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition ${active ? "bg-indigo-50 text-indigo-700 dark:bg-indigo-500/10 dark:text-indigo-300" : "text-[var(--muted)] hover:bg-[var(--subtle)] hover:text-[var(--fg)]"}`}>
                <Icon className="size-4" />{label}
              </Link>
            );
          })}
          <div className="my-4 border-t border-[var(--border)]" />
          <Link to="/notifications" className="sidebar-link"><Bell className="size-4" />Notifications</Link>
          <Link to="/settings" className="sidebar-link"><Settings className="size-4" />Settings</Link>
          <Link to="/help" className="sidebar-link"><CircleHelp className="size-4" />Help</Link>
        </nav>
        <div className="border-t border-[var(--border)] p-3">
          <Link to="/settings" className="flex items-center gap-3 rounded-lg p-2 hover:bg-[var(--subtle)]">
            <span className="grid size-9 place-items-center rounded-full bg-indigo-600 text-xs font-semibold text-white">{user.initials}</span>
            <span><b className="block text-sm font-medium">{user.name}</b><small className="text-[var(--muted)]">{user.plan} plan</small></span>
          </Link>
        </div>
      </aside>
      <div className="lg:pl-64">
        <header className="sticky top-0 z-30 flex h-16 items-center border-b border-[var(--border)] bg-[color:var(--bg)]/95 px-4 backdrop-blur lg:px-6">
          <button className="icon-button lg:hidden" onClick={() => setMenuOpen(true)} aria-label="Open menu"><Menu className="size-4" /></button>
          <button className="ml-auto icon-button" onClick={() => setDark((value) => !value)} aria-label="Toggle theme">{dark ? <Sun className="size-4" /> : <Moon className="size-4" />}</button>
          <Link to="/notifications" className="relative ml-1 icon-button" aria-label="Notifications"><Bell className="size-4" /><span className="absolute right-1 top-1 size-2 rounded-full bg-red-500" /></Link>
          <span className="ml-2 grid size-8 place-items-center rounded-full bg-indigo-600 text-xs font-semibold text-white">{user.initials}</span>
        </header>
        <main className="mx-auto max-w-[1440px] p-4 pb-24 sm:p-6 lg:p-8">{children}</main>
      </div>
    </div>
  );
}
