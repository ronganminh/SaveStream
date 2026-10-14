import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";
import { useEffect, type ReactNode } from "react";

import { Toaster } from "@/components/ui/sonner";
import { AuthProvider } from "@/auth/auth-context";
import { AuthRouteGuard } from "@/auth/auth-guards";
import { PublicNotFoundPage } from "@/components/public/contact-status";
import {
  PreferencesProvider,
  themeInitScript,
  usePreferences,
} from "@/lib/preferences";
import appCss from "../styles.css?url";
import { reportLovableError } from "../lib/lovable-error-reporting";
import { pageTitle } from "@/lib/route-metadata";

function NotFoundComponent() {
  return <PublicNotFoundPage />;
}

function ErrorComponent({ error, reset }: { error: Error; reset: () => void }) {
  console.error(error);
  const router = useRouter();
  const { t } = usePreferences();
  useEffect(() => {
    reportLovableError(error, { boundary: "tanstack_root_error_component" });
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-xl font-semibold tracking-tight text-foreground">
          {t("This page didn't load")}
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {t("Something went wrong on our end. You can try refreshing or head back home.")}
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-2">
          <button
            onClick={() => {
              router.invalidate();
              reset();
            }}
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            {t("Try again")}
          </button>
          <a
            href="/"
            className="inline-flex items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
          >
            {t("Go home")}
          </a>
        </div>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: ({ match }) => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      ...(match.globalNotFound
        ? [
            { title: pageTitle("Page not found") },
            { property: "og:title", content: pageTitle("Page not found") },
          ]
        : [{ title: pageTitle("Automatic TikTok LIVE recording") }]),
      { name: "description", content: "Automatic TikTok livestream recording in the cloud." },
      { name: "author", content: "SaveStream" },
      { name: "theme-color", content: "#6D4AFF" },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [
      {
        rel: "stylesheet",
        href: appCss,
      },
      { rel: "icon", href: "/favicon.svg", type: "image/svg+xml" },
      { rel: "icon", href: "/favicon-32.png", sizes: "32x32", type: "image/png" },
      { rel: "icon", href: "/favicon-16.png", sizes: "16x16", type: "image/png" },
      { rel: "apple-touch-icon", href: "/apple-touch-icon.png" },
      { rel: "manifest", href: "/site.webmanifest" },
      { rel: "preconnect", href: "https://fonts.googleapis.com" },
      { rel: "preconnect", href: "https://fonts.gstatic.com", crossOrigin: "anonymous" },
      {
        rel: "stylesheet",
        href: "https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap",
      },
    ],
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});

function RootShell({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}

function SkipLink() {
  const { t } = usePreferences();
  return (
    <a
      href="#main-content"
      className="fixed left-3 top-3 z-[var(--z-toast)] -translate-y-24 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground shadow-lg transition-transform focus:translate-y-0"
    >
      {t("Skip to content")}
    </a>
  );
}

function RootComponent() {
  const { queryClient } = Route.useRouteContext();

  return (
    <PreferencesProvider>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <SkipLink />
          <div id="main-content" tabIndex={-1}>
            {/* Required: nested routes render here. Removing <Outlet /> breaks all child routes. */}
            <AuthRouteGuard>
              <Outlet />
            </AuthRouteGuard>
          </div>
          <Toaster position="bottom-right" />
        </AuthProvider>
      </QueryClientProvider>
    </PreferencesProvider>
  );
}