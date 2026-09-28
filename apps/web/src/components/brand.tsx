import { Link } from "@tanstack/react-router";

export function SaveStreamMark({ className = "size-8" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 64 64" fill="none" aria-hidden="true">
      <rect width="64" height="64" rx="14" fill="#4F46E5" />
      <path
        d="M46 17C40 10 25 10 19 19C13 28 22 32 33 35C44 38 50 44 44 51C37 59 23 57 17 49"
        stroke="white"
        strokeWidth="8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="46" cy="44" r="4.5" fill="#C4B5FD" />
    </svg>
  );
}

export function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <Link to="/" className="brand-logo inline-flex min-w-0 items-center gap-2.5 font-semibold tracking-tight">
      <SaveStreamMark className="size-8 shrink-0" />
      {!compact && <span className="brand-wordmark truncate">SaveStream</span>}
    </Link>
  );
}
