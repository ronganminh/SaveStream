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
  signInWithSocial: (provider: SocialProvider) => Promise<AuthUser>;
  signOut: () => Promise<void>;
  signOutEverywhere: () => Promise<void>;
  refreshSession: () => Promise<AuthUser | null>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>(
    isDemoMode ? "authenticated" : "bootstrapping",
  );
  const [user, setUser] = useState<AuthUser | null>(null);
  const accessTokenRef = useRef<string | null>(null);
  const pendingSocialLinkRef = useRef<string | null>(null);
  const refreshInFlightRef = useRef<Promise<string | null> | null>(null);

  const clearSession = useCallback(() => {
    accessTokenRef.current = null;
    pendingSocialLinkRef.current = null;
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
      .catch(() => null)
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

  const loadCurrentUser = useCallback(
    async (accessToken: string): Promise<AuthUser> => {
      const currentUser = await authApi.getCurrentUser(accessToken);
      accessTokenRef.current = accessToken;
      setUser(currentUser);
      setStatus("authenticated");
      return currentUser;
    },
    [],
  );

  useEffect(() => {
    if (isDemoMode) return;
    let cancelled = false;

    void (async () => {
      const token = await refreshAccessToken();
      if (cancelled) return;
      if (!token) {
        clearSession();
        return;
      }

      try {
        const currentUser = await authApi.getCurrentUser(token);
        if (cancelled) return;
        accessTokenRef.current = token;
        setUser(currentUser);
        setStatus("authenticated");
      } catch {
        if (!cancelled) clearSession();
      }
    })();

    return () => {
      cancelled = true;
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
    async (provider: SocialProvider): Promise<AuthUser> => {
      if (isDemoMode) {
        throw new Error("Social sign-in is not available in the demo.");
      }
      pendingSocialLinkRef.current = null;
      const firebaseIdToken = await requestFirebaseIdToken(provider);
      try {
        const tokens = await authApi.socialLogin(firebaseIdToken);
        return await loadCurrentUser(tokens.access_token);
      } catch (error) {
        if (error instanceof ApiError && error.code === "AUTH_ACCOUNT_LINK_REQUIRED") {
          // Keep only in memory. After explicit password sign-in, the user can
          // approve linking the Google/Apple identity to the existing account.
          pendingSocialLinkRef.current = firebaseIdToken;
        }
        throw error;
      }
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
    } catch {
      clearSession();
      return null;
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
      signOut,
      signOutEverywhere,
      refreshSession,
    }),
    [identity, refreshSession, signIn, signInWithSocial, signOut, signOutEverywhere, status, user],
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
