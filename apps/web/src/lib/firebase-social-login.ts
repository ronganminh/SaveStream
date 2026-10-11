/** Firebase acts only as an identity provider. SaveStream owns app sessions. */
export type SocialProvider = "google" | "apple";

const config = {
  apiKey: import.meta.env["VITE_FIREBASE_API_KEY"]?.trim() ?? "",
  authDomain: import.meta.env["VITE_FIREBASE_AUTH_DOMAIN"]?.trim() ?? "",
  projectId: import.meta.env["VITE_FIREBASE_PROJECT_ID"]?.trim() ?? "",
  appId: import.meta.env["VITE_FIREBASE_APP_ID"]?.trim() ?? "",
};

export const firebaseSocialConfigured = Object.values(config).every(Boolean);

export async function requestFirebaseIdToken(provider: SocialProvider): Promise<string> {
  if (!firebaseSocialConfigured || typeof window === "undefined") {
    throw new Error("Social sign-in has not been configured.");
  }

  // Dynamic import keeps Firebase Auth out of server-side page rendering.
  const [{ getApps, initializeApp }, firebaseAuth] = await Promise.all([
    import("firebase/app"),
    import("firebase/auth"),
  ]);
  const app =
    getApps().find((candidate) => candidate.name === "savestream-social") ??
    initializeApp(config, "savestream-social");

  const auth = firebaseAuth.getAuth(app);
  await firebaseAuth.setPersistence(auth, firebaseAuth.inMemoryPersistence);
  const providerConfig =
    provider === "google"
      ? new firebaseAuth.GoogleAuthProvider()
      : new firebaseAuth.OAuthProvider("apple.com");
  if (provider === "apple") {
    providerConfig.addScope("email");
    providerConfig.addScope("name");
  }

  const credential = await firebaseAuth.signInWithPopup(auth, providerConfig);
  try {
    return await credential.user.getIdToken(true);
  } finally {
    // Do not persist a separate Firebase account session in web storage.
    await firebaseAuth.signOut(auth);
  }
}

export function socialProviderErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message === "Social sign-in has not been configured.") {
    return error.message;
  }
  const code = (error as { code?: unknown } | null)?.code;
  switch (code) {
    case "auth/popup-closed-by-user":
    case "auth/cancelled-popup-request":
      return "Sign-in was cancelled.";
    case "auth/popup-blocked":
      return "Allow pop-ups for SaveStream and try again.";
    case "auth/account-exists-with-different-credential":
      return "This email already uses another sign-in method. Sign in with that method first.";
    case "auth/operation-not-allowed":
    case "auth/unauthorized-domain":
      return "This sign-in provider has not yet been enabled for SaveStream.";
    default:
      return "Google/Apple sign-in could not be completed. Please try again.";
  }
}
