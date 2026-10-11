import { defineConfig, devices } from "@playwright/test";

const baseURL = process.env.SAVESTREAM_E2E_BASE_URL || "https://savestream.online";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  timeout: 30_000,
  expect: { timeout: 10_000 },
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL,
    storageState: "./e2e/.auth/user.json",
    trace: "off",
    video: "off",
    screenshot: "off",
    ignoreHTTPSErrors: false,
  },
  projects: [
    {
      name: "desktop-chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "mobile-chromium",
      use: { ...devices["Pixel 7"] },
    },
  ],
  globalSetup: "./e2e/global-setup.ts",
});
