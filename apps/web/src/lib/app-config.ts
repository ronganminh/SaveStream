export type AppMode = "demo" | "production";
export type AppRole = "guest" | "user" | "owner" | "support" | "finance" | "admin";

const requestedMode = import.meta.env["VITE_APP_MODE"]?.trim();
if (requestedMode && requestedMode !== "demo" && requestedMode !== "production") {
  throw new Error("VITE_APP_MODE must be either demo or production.");
}
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
  if (isProductionMode && parsed.protocol !== "https:") {
    throw new Error("VITE_API_BASE_URL must use https when VITE_APP_MODE=production.");
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

const requestedBillingCheckout = import.meta.env["VITE_BILLING_CHECKOUT_ENABLED"];
export const billingCheckoutEnabled =
  isDemoMode || requestedBillingCheckout?.trim().toLowerCase() === "true";

/**
 * Route-access contract. Real auth/session state is supplied by AuthProvider.
 */
export type FrontendIdentity = {
  authenticated: boolean;
  role: AppRole;
};

export const ADMIN_ROLES = ["owner", "support", "finance", "admin"] as const;

export function isAdminRole(role: AppRole): boolean {
  return (ADMIN_ROLES as readonly string[]).includes(role);
}

export type RouteAccess = {
  visibility: "public" | "authenticated" | "admin";
  requiresAuth: boolean;
  requiredRole?: "admin";
  indexable: boolean;
};

export function canAccessRoute(access: RouteAccess, identity: FrontendIdentity) {
  if (access.requiresAuth && !identity.authenticated) return false;
  if (access.requiredRole === "admin" && !isAdminRole(identity.role)) return false;
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
  "/onboarding",
] as const;

/** Public, indexable marketing and policy pages (also listed in public/sitemap.xml). */
export const PUBLIC_INDEXABLE_PATHS: readonly string[] = [
  "/",
  "/pricing",
  "/help",
  "/contact",
  "/terms",
  "/privacy",
  "/acceptable-use",
  "/refund",
];

export function getRouteAccess(pathname: string): RouteAccess {
  if (pathname.startsWith("/admin")) {
    return { visibility: "admin", requiresAuth: true, requiredRole: "admin", indexable: false };
  }
  if (protectedPrefixes.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`))) {
    return { visibility: "authenticated", requiresAuth: true, indexable: false };
  }
  const indexable = PUBLIC_INDEXABLE_PATHS.includes(pathname);
  return { visibility: "public", requiresAuth: false, indexable };
}

