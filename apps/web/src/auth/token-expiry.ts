// No "@/..." imports: the auth audit unit-tests this module with plain node.

/** Refresh the access token this long before it expires. */
export const EARLY_REFRESH_MS = 60_000;

/** Expiry (ms since epoch) from a JWT's `exp` claim, or null if unreadable. */
export function accessTokenExpiresAt(token: string | null | undefined): number | null {
  const payload = token?.split(".")[1];
  if (!payload) return null;
  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
    const claims = JSON.parse(atob(padded)) as { exp?: unknown };
    return typeof claims.exp === "number" ? claims.exp * 1000 : null;
  } catch {
    return null;
  }
}

/**
 * True when the token expires within `leewayMs`, so the next API call should
 * refresh first instead of failing with 401 and retrying.
 */
export function needsEarlyRefresh(
  token: string | null | undefined,
  now: number = Date.now(),
  leewayMs: number = EARLY_REFRESH_MS,
): boolean {
  const expiresAt = accessTokenExpiresAt(token);
  return expiresAt !== null && expiresAt - now <= leewayMs;
}
