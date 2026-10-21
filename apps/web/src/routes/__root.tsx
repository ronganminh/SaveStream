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
import { initAnalytics } from "@/lib/analytics";
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
import { ApiError } from "@/api/errors";
import {
  MaintenanceGate,
  OfflineBanner,
  OfflineErrorScreen,
  ServerErrorScreen,
} from "@/components/system/system-pages";

function NotFoundComponent() {
  return <PublicNotFoundPage />;
}

function ErrorComponent({ error, reset }: { error: Error; reset: () => void }) {
  console.error(error);
  const router = useRouter();
  useEffect(() => {
    reportLovableError(error, { boundary: "tanstack_root_error_component" });
  }, [error]);

  // The root error component replaces RootComponent, so it needs its own
  // PreferencesProvider: the error screens render the logo and translated copy.
  const retry = () => {
    router.invalidate();
    reset();
  };
  return (
    <PreferencesProvider>
      {error instanceof ApiError && error.status === 0 ? (
        <OfflineErrorScreen onRetry={retry} />
      ) : (
        <ServerErrorScreen
          requestId={error instanceof ApiError ? error.requestId : undefined}
          onRetry={retry}
        />
      )}
    </PreferencesProvider>
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
  useEffect(() => initAnalytics(), []);

  return (
    <PreferencesProvider>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <SkipLink />
          <div id="main-content" tabIndex={-1}>
            {/* Required: nested routes render here. Removing <Outlet /> breaks all child routes. */}
            <MaintenanceGate>
              <AuthRouteGuard>
                <Outlet />
              </AuthRouteGuard>
            </MaintenanceGate>
          </div>
          <OfflineBanner />
          <Toaster position="bottom-right" />
        </AuthProvider>
      </QueryClientProvider>
    </PreferencesProvider>
  );
}