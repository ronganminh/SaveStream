import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { authApi, type AuthRole, type AuthUser } from "@/api/auth";
import { configureApiSession } from "@/api/client";
import { isDemoMode } from "@/lib/app-config";
import { ApiError } from "@/api/errors";
import { authErrorMessage } from "@/api/auth";
import { requestFirebaseIdToken, type SocialProvider } from "@/lib/firebase-social-login";
import type { LegalConsent } from "@/lib/legal";
import { toast } from "sonner";

export type AuthStatus = "bootstrapping" | "authenticated" | "guest";

type AuthIdentity = {
  authenticated: boolean;
  role: "guest" | AuthRole;
};

type AuthContextValue = {
  status: AuthStatus;
  user: AuthUser | null;
  identity: AuthIdentity;
  signIn: (email: string, password: string) => Promise<AuthUser>;
  /**
   * Google/Apple sign-in. A first sign-in creates an account and needs the
   * 18+ / Terms / Privacy consent: without it this throws ApiError
   * LEGAL_CONSENT_REQUIRED and keeps the provider token so
   * completeSocialSignUp can finish after the user agrees.
   */
  signInWithSocial: (provider: SocialProvider, consent?: LegalConsent) => Promise<AuthUser>;
  completeSocialSignUp: (consent: LegalConsent) => Promise<AuthUser>;
  signOut: () => Promise<void>;
  signOutEverywhere: () => Promise<void>;
  refreshSession: () => Promise<AuthUser | null>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

// The refresh cookie is httpOnly on the API domain, so the web app cannot
// see it. This first-party marker holds no credential; it only decides
// whether to show a "Restoring your session…" spinner or the signed-out UI
// right away while the refresh call runs in the background.
const SESSION_HINT_COOKIE = "ss_signed_in";
const SESSION_HINT_MAX_AGE_SECONDS = 60 * 60 * 24 * 30;

function readSessionHint(): boolean {
  if (typeof document === "undefined") return true;
  return document.cookie.split("; ").some((part) => part === `${SESSION_HINT_COOKIE}=1`);
}

function writeSessionHint(present: boolean) {
  if (typeof document === "undefined") return;
  const secure = window.location.protocol === "https:" ? "; Secure" : "";
  document.cookie = present
    ? `${SESSION_HINT_COOKIE}=1; Path=/; Max-Age=${SESSION_HINT_MAX_AGE_SECONDS}; SameSite=Lax${secure}`
    : `${SESSION_HINT_COOKIE}=; Path=/; Max-Age=0; SameSite=Lax${secure}`;
}

function isSessionRejected(error: unknown): boolean {
  return error instanceof ApiError && (error.status === 401 || error.status === 403);
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>(isDemoMode ? "authenticated" : "bootstrapping");
  const [user, setUser] = useState<AuthUser | null>(null);
  const accessTokenRef = useRef<string | null>(null);
  const pendingSocialLinkRef = useRef<string | null>(null);
  const pendingSocialSignUpRef = useRef<string | null>(null);
  const refreshInFlightRef = useRef<Promise<string | null> | null>(null);

  const clearSession = useCallback(() => {
    accessTokenRef.current = null;
    pendingSocialLinkRef.current = null;
    writeSessionHint(false);
    setUser(null);
    setStatus(isDemoMode ? "authenticated" : "guest");
  }, []);

  const refreshAccessToken = useCallback(async (): Promise<string | null> => {
    if (isDemoMode) return null;
    if (refreshInFlightRef.current) return refreshInFlightRef.current;

    const refreshPromise = authApi
      .refresh()
      .then((result) => {
        accessTokenRef.current = result.access_token;
        return result.access_token;
      })
      .catch((error: unknown) => {
        if (isSessionRejected(error)) return null;
        throw error;
      })
      .finally(() => {
        refreshInFlightRef.current = null;
      });

    refreshInFlightRef.current = refreshPromise;
    return refreshPromise;
  }, []);

  useEffect(() => {
    configureApiSession({
      getAccessToken: () => accessTokenRef.current,
      refreshAccessToken,
      onAuthExpired: clearSession,
    });
    return () => configureApiSession(null);
  }, [clearSession, refreshAccessToken]);

  const loadCurrentUser = useCallback(async (accessToken: string): Promise<AuthUser> => {
    const currentUser = await authApi.getCurrentUser(accessToken);
    accessTokenRef.current = accessToken;
    writeSessionHint(true);
    setUser(currentUser);
    setStatus("authenticated");
    return currentUser;
  }, []);

  useEffect(() => {
    if (isDemoMode) return;
    let cancelled = false;
    let retryTimer: ReturnType<typeof setTimeout> | undefined;
    let retryAttempt = 0;
    // No hint means this browser never kept a session (or signed out): show
    // the signed-out UI immediately and only upgrade if the refresh works.
    const expectSession = readSessionHint();
    if (!expectSession) setStatus("guest");

    const bootstrapSession = async () => {
      try {
        const token = await refreshAccessToken();
        if (cancelled) return;
        if (!token) {
          clearSession();
          return;
        }
        const currentUser = await authApi.getCurrentUser(token);
        if (cancelled) return;
        accessTokenRef.current = token;
        writeSessionHint(true);
        setUser(currentUser);
        setStatus("authenticated");
        retryAttempt = 0;
      } catch (error) {
        if (cancelled) return;
        if (isSessionRejected(error)) {
          clearSession();
          return;
        }
        // Already showing the signed-out UI; don't keep retrying silently.
        if (!expectSession) return;
        // Preserve the refresh cookie and any in-memory token on transient
        // network, rate-limit, or server errors. A later successful request
        // restores the same session instead of redirecting to sign-in.
        const retryDelayMs = Math.min(1_000 * 2 ** retryAttempt, 10_000);
        retryAttempt += 1;
        retryTimer = setTimeout(() => void bootstrapSession(), retryDelayMs);
      }
    };

    void bootstrapSession();

    return () => {
      cancelled = true;
      if (retryTimer) clearTimeout(retryTimer);
    };
  }, [clearSession, refreshAccessToken]);

  const signIn = useCallback(
    async (email: string, password: string): Promise<AuthUser> => {
      if (isDemoMode) {
        setStatus("authenticated");
        return {
          id: "demo",
          role: "owner",
          email,
          email_verified: true,
          display_name: "Demo Owner",
          locale: "en",
          created_at: new Date(0).toISOString(),
          admin_mfa_enabled: true,
          admin_mfa_verified: true,
        };
      }

      const tokens = await authApi.login(email, password);
      const signedIn = await loadCurrentUser(tokens.access_token);
      const pendingSocialIdToken = pendingSocialLinkRef.current;
      pendingSocialLinkRef.current = null;
      if (pendingSocialIdToken) {
        try {
          await authApi.linkSocial(pendingSocialIdToken, password);
          toast.success("Your Google or Apple account is now linked.");
        } catch (error) {
          toast.error("Signed in, but unable to link provider: " + authErrorMessage(error));
        }
      }
      return signedIn;
    },
    [loadCurrentUser],
  );

  const signInWithSocial = useCallback(
    async (provider: SocialProvider, consent?: LegalConsent): Promise<AuthUser> => {
      if (isDemoMode) {
        throw new Error("Social sign-in is not available in the demo.");
      }
      pendingSocialLinkRef.current = null;
      pendingSocialSignUpRef.current = null;
      const firebaseIdToken = await requestFirebaseIdToken(provider);
      try {
        const tokens = await authApi.socialLogin(firebaseIdToken, consent);
        return await loadCurrentUser(tokens.access_token);
      } catch (error) {
        if (error instanceof ApiError && error.code === "AUTH_ACCOUNT_LINK_REQUIRED") {
          // Keep only in memory. After explicit password sign-in, the user can
          // approve linking the Google/Apple identity to the existing account.
          pendingSocialLinkRef.current = firebaseIdToken;
        }
        if (error instanceof ApiError && error.code === "LEGAL_CONSENT_REQUIRED") {
          // New account: kept in memory only until the user agrees.
          pendingSocialSignUpRef.current = firebaseIdToken;
        }
        throw error;
      }
    },
    [loadCurrentUser],
  );

  const completeSocialSignUp = useCallback(
    async (consent: LegalConsent): Promise<AuthUser> => {
      const firebaseIdToken = pendingSocialSignUpRef.current;
      if (!firebaseIdToken) {
        throw new Error("Your Google or Apple sign-in expired. Please try again.");
      }
      const tokens = await authApi.socialLogin(firebaseIdToken, consent);
      pendingSocialSignUpRef.current = null;
      return loadCurrentUser(tokens.access_token);
    },
    [loadCurrentUser],
  );

  const signOut = useCallback(async () => {
    if (isDemoMode) return;
    try {
      if (accessTokenRef.current) await authApi.logout();
    } finally {
      clearSession();
    }
  }, [clearSession]);

  const signOutEverywhere = useCallback(async () => {
    if (isDemoMode) return;
    try {
      if (accessTokenRef.current) await authApi.logoutAll();
    } finally {
      clearSession();
    }
  }, [clearSession]);

  const refreshSession = useCallback(async (): Promise<AuthUser | null> => {
    if (isDemoMode) return user;
    const token = await refreshAccessToken();
    if (!token) {
      clearSession();
      return null;
    }
    try {
      return await loadCurrentUser(token);
    } catch (error) {
      if (isSessionRejected(error)) {
        clearSession();
        return null;
      }
      throw error;
    }
  }, [clearSession, loadCurrentUser, refreshAccessToken, user]);

  const identity = useMemo<AuthIdentity>(() => {
    if (isDemoMode) return { authenticated: true, role: "owner" };
    if (status === "authenticated" && user) {
      return { authenticated: true, role: user.role };
    }
    return { authenticated: false, role: "guest" };
  }, [status, user]);

  const value = useMemo<AuthContextValue>(
    () => ({
      status,
      user,
      identity,
      signIn,
      signInWithSocial,
      completeSocialSignUp,
      signOut,
      signOutEverywhere,
      refreshSession,
    }),
    [
      completeSocialSignUp,
      identity,
      refreshSession,
      signIn,
      signInWithSocial,
      signOut,
      signOutEverywhere,
      status,
      user,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside AuthProvider.");
  return value;
}

export function useCurrentUser(): AuthUser | null {
  return useAuth().user;
}
