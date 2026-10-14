import { useEffect, type ReactNode } from "react";
import { useNavigate, useRouterState } from "@tanstack/react-router";

import { useAuth } from "@/auth/auth-context";
import { canAccessRoute, getRouteAccess } from "@/lib/app-config";
import { RestoringSessionScreen } from "@/components/system/system-pages";
import { SessionExpiredDialog } from "@/components/app/shell-extras";

function SessionGate({ message }: { message: string }) {
  return (
    <div className="grid min-h-screen place-items-center bg-background px-4">
      <div className="text-center">
        <span className="mx-auto block size-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
        <p className="mt-4 text-sm text-muted-foreground">{message}</p>
      </div>
    </div>
  );
}

export function AuthRouteGuard({ children }: { children: ReactNode }) {
  const path = useRouterState({ select: (state) => state.location.pathname });
  const navigate = useNavigate();
  const { status, identity, sessionExpired } = useAuth();
  const access = getRouteAccess(path);
  const allowed = canAccessRoute(access, identity);
  const checkingProtectedRoute = access.requiresAuth && status === "bootstrapping";
  // A session that was rejected mid-use asks before leaving the page.
  const showSessionExpired = access.requiresAuth && !allowed && sessionExpired;

  useEffect(() => {
    if (checkingProtectedRoute || allowed || showSessionExpired) return;
    void navigate({
      to: identity.authenticated ? "/overview" : "/sign-in",
      replace: true,
    });
  }, [allowed, checkingProtectedRoute, identity.authenticated, navigate, showSessionExpired]);

  if (checkingProtectedRoute) return <RestoringSessionScreen />;
  if (showSessionExpired) return <SessionExpiredDialog />;
  if (!allowed) {
    return (
      <SessionGate
        message={
          identity.authenticated ? "Returning to your workspace…" : "Redirecting to sign in…"
        }
      />
    );
  }

  return children;
}
