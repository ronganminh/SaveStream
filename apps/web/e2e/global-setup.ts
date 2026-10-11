import { request, type FullConfig } from "@playwright/test";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export default async function globalSetup(config: FullConfig) {
  const email = process.env.SAVESTREAM_E2E_EMAIL;
  const password = process.env.SAVESTREAM_E2E_PASSWORD;
  const statePath = resolve(
    dirname(fileURLToPath(import.meta.url)),
    ".auth/user.json",
  );
  await mkdir(dirname(statePath), { recursive: true });

  if (!email || !password) {
    await writeFile(
      statePath,
      JSON.stringify({ cookies: [], origins: [] }, null, 2),
      "utf8",
    );
    return;
  }

  const webBaseURL = String(
    config.projects[0]?.use.baseURL ?? "https://savestream.online",
  );
  const apiBaseURL =
    process.env.SAVESTREAM_E2E_API_URL || "https://api.savestream.online";
  const origin = new URL(webBaseURL).origin;

  const api = await request.newContext({
    baseURL: apiBaseURL,
    extraHTTPHeaders: { Origin: origin },
  });

  const response = await api.post("/v1/auth/login", {
    data: { email, password, client_type: "web" },
  });
  if (!response.ok()) {
    throw new Error(`E2E login failed with HTTP ${response.status()}.`);
  }

  const body = (await response.json()) as { access_token?: string };
  if (!body.access_token) {
    throw new Error("E2E login response did not include an access token.");
  }

  const me = await api.get("/v1/me", {
    headers: { Authorization: `Bearer ${body.access_token}` },
  });
  if (!me.ok()) {
    throw new Error(`E2E /v1/me check failed with HTTP ${me.status()}.`);
  }

  await api.storageState({ path: statePath });
  await api.dispose();
}
