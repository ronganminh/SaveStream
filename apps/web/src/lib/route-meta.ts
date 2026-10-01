import { redirect } from "@tanstack/react-router";
import {
  appMode,
  canAccessRoute,
  productionBackendConnected,
  type FrontendIdentity,
  type RouteAccess,
} from "@/lib/app-config";

export type RouteVisibility = RouteAccess["visibility"];

type RoutePolicy = RouteAccess & {
  id: string;
  match: (path: string) => boolean;
};

const exact = (target: string) => (path: string) => path === target;
const prefix = (target: string) => (path: string) => path === target || path.startsWith(target + "/");

const publicIndexable = (id: string, path: string): RoutePolicy => ({
  id,
  match: exact(path),
  visibility: "public",
  requiresAuth: false,
  indexable: true,
});

const publicNoIndex = (id: string, path: string): RoutePolicy => ({
  id,
  match: exact(path),
  visibility: "public",
  requiresAuth: false,
  indexable: false,
});

const authenticated = (id: string, path: string): RoutePolicy => ({
  id,
  match: prefix(path),
  visibility: "authenticated",
  requiresAuth: true,
  indexable: false,
});

export const routePolicies: readonly RoutePolicy[] = [
  publicIndexable("home", "/"),
  publicIndexable("pricing", "/pricing"),
  publicIndexable("help", "/help"),
  publicIndexable("contact", "/contact"),
  publicIndexable("terms", "/terms"),
  publicIndexable("privacy", "/privacy"),
  publicIndexable("acceptable-use", "/acceptable-use"),

  publicNoIndex("status", "/status"),
  publicNoIndex("sign-in", "/sign-in"),
  publicNoIndex("sign-up", "/sign-up"),
  publicNoIndex("forgot-password", "/forgot-password"),
  publicNoIndex("reset-password", "/reset-password"),
  publicNoIndex("auth-error", "/auth/error"),

  {
    id: "verify-email",
    match: prefix("/verify-email"),
    visibility: "public",
    requiresAuth: false,
    indexable: false,
  },

  authenticated("overview", "/overview"),
  authenticated("channels", "/channels"),
  authenticated("recordings", "/recordings"),
  authenticated("usage", "/usage"),
  authenticated("billing", "/billing"),
  authenticated("notifications", "/notifications"),
  authenticated("settings", "/settings"),
  authenticated("onboarding", "/onboarding"),

  {
    id: "admin",
    match: prefix("/admin"),
    visibility: "admin",
    requiresAuth: true,
    requiredRole: "admin",
    indexable: false,
  },
];

const fallbackPolicy: RoutePolicy = {
  id: "unknown",
  match: () => true,
  visibility: "public",
  requiresAuth: false,
  indexable: false,
};

export function getRouteAccess(path: string): RoutePolicy {
  return routePolicies.find((policy) => policy.match(path)) ?? fallbackPolicy;
}

export function getFrontendIdentity(): FrontendIdentity {
  if (appMode === "demo") {
    return { source: "demo", authenticated: true, role: "admin" };
  }

  // Fail closed until a real production auth provider supplies identity.
  if (!productionBackendConnected) {
    return { source: "production", authenticated: false, role: "guest" };
  }

  return { source: "production", authenticated: false, role: "guest" };
}

export function canAccessPath(path: string, identity = getFrontendIdentity()) {
  return canAccessRoute(getRouteAccess(path), identity);
}

export function requireRouteAccess(path: string) {
  const identity = getFrontendIdentity();
  const access = getRouteAccess(path);

  if (!canAccessRoute(access, identity)) {
    throw redirect({ to: "/sign-in" });
  }

  return { identity, access };
}
