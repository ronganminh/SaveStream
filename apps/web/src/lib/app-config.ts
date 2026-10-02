export type AppMode = "demo" | "production";
export type AppRole = "guest" | "user" | "admin";

const requestedMode = import.meta.env["VITE_APP_MODE"];
export const appMode: AppMode = requestedMode === "production" ? "production" : "demo";
export const isDemoMode = appMode === "demo";
export const isProductionMode = appMode === "production";

function resolveApiBaseUrl(value: string | undefined): string {
  const candidate = value?.trim() ?? "";
  if (!candidate) {
    if (isProductionMode) {
      throw new Error("VITE_API_BASE_URL is required when VITE_APP_MODE=production.");
    }
    return "";
  }

  let parsed: URL;
  try {
    parsed = new URL(candidate);
  } catch {
    throw new Error("VITE_API_BASE_URL must be an absolute http(s) URL.");
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("VITE_API_BASE_URL must use http or https.");
  }
  if (parsed.username || parsed.password) {
    throw new Error("VITE_API_BASE_URL must not contain credentials.");
  }
  if (parsed.search || parsed.hash) {
    throw new Error("VITE_API_BASE_URL must not contain a query string or fragment.");
  }

  return parsed.toString().replace(/\/$/, "");
}

export const apiBaseUrl = resolveApiBaseUrl(import.meta.env["VITE_API_BASE_URL"]);
export const apiConfigured = apiBaseUrl.length > 0;
export const productionBackendConnected = isProductionMode && apiConfigured;

/**
 * Route-access contract. Real auth/session state is supplied by AuthProvider.
 */
export type FrontendIdentity = {
  authenticated: boolean;
  role: AppRole;
};

export type RouteAccess = {
  visibility: "public" | "authenticated" | "admin";
  requiresAuth: boolean;
  requiredRole?: "admin";
  indexable: boolean;
};

export function canAccessRoute(access: RouteAccess, identity: FrontendIdentity) {
  if (access.requiresAuth && !identity.authenticated) return false;
  if (access.requiredRole === "admin" && identity.role !== "admin") return false;
  return true;
}

const protectedPrefixes = [
  "/overview",
  "/channels",
  "/recordings",
  "/usage",
  "/billing",
  "/notifications",
  "/settings",
  "/help",
  "/onboarding",
] as const;

export function getRouteAccess(pathname: string): RouteAccess {
  if (pathname.startsWith("/admin")) {
    return { visibility: "admin", requiresAuth: true, requiredRole: "admin", indexable: false };
  }
  if (protectedPrefixes.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`))) {
    return { visibility: "authenticated", requiresAuth: true, indexable: false };
  }
  const indexable = ["/", "/pricing", "/privacy", "/terms", "/acceptable-use"].includes(pathname);
  return { visibility: "public", requiresAuth: false, indexable };
}

