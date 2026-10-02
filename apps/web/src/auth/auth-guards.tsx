import { useEffect, type ReactNode } from "react";
import { useNavigate, useRouterState } from "@tanstack/react-router";

import { useAuth } from "@/auth/auth-context";
import { canAccessRoute, getRouteAccess } from "@/lib/app-config";

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
  const { status, identity } = useAuth();
  const access = getRouteAccess(path);
  const allowed = canAccessRoute(access, identity);
  const checkingProtectedRoute = access.requiresAuth && status === "bootstrapping";

  useEffect(() => {
    if (checkingProtectedRoute || allowed) return;
    void navigate({
      to: identity.authenticated ? "/overview" : "/sign-in",
      replace: true,
    });
  }, [allowed, checkingProtectedRoute, identity.authenticated, navigate]);

  if (checkingProtectedRoute) return <SessionGate message="Restoring your session…" />;
  if (!allowed) {
    return (
      <SessionGate
        message={identity.authenticated ? "Returning to your workspace…" : "Redirecting to sign in…"}
      />
    );
  }

  return children;
}
