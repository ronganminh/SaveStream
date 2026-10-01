export type AppMode = "demo" | "production";
export type AppRole = "guest" | "user" | "admin";

const requestedMode = import.meta.env["VITE_APP_MODE"];
export const appMode: AppMode = requestedMode === "production" ? "production" : "demo";
export const isDemoMode = appMode === "demo";
export const isProductionMode = appMode === "production";

/**
 * Frontend-only access contract. A real auth provider can replace this context
 * later without changing route visibility rules or presentation components.
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

export const productionBackendConnected = false;
