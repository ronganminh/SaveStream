import { expect, test, type Page } from "@playwright/test";

function collectClientErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      errors.push(`console.error: ${message.text()}`);
    }
  });
  return errors;
}

async function expectAuthenticatedShell(page: Page) {
  await expect(page.getByRole("button", { name: "Account menu" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Buy credits" }).first()).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Main navigation" })).toHaveCount(1);
}

async function openWorkspaceMenuIfNeeded(page: Page) {
  const button = page.getByRole("button", { name: "Open menu" });
  if (await button.isVisible()) await button.click();
}

test.describe("production authenticated UX", () => {
  test.skip(
    !process.env.SAVESTREAM_E2E_EMAIL || !process.env.SAVESTREAM_E2E_PASSWORD,
    "Production credentials are not configured.",
  );

  test("restores the cookie session and loads the workspace", async ({ page }) => {
    const errors = collectClientErrors(page);
    await page.goto("/overview");
    await expect(page).toHaveURL(/\/overview$/);
    await expectAuthenticatedShell(page);
    await expect(page.getByRole("heading", { name: "Overview" })).toBeVisible();
    expect(errors).toEqual([]);
  });

  test("opening Help keeps the authenticated app shell", async ({ page }) => {
    const errors = collectClientErrors(page);
    await page.goto("/overview");
    await openWorkspaceMenuIfNeeded(page);
    await page.getByRole("link", { name: "Help" }).click();
    await expect(page).toHaveURL(/\/help$/);
    await expectAuthenticatedShell(page);
    await expect(page.getByRole("heading", { name: "Help" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Billing" })).toBeVisible();
    expect(errors).toEqual([]);
  });

  test("Contact support from Help stays inside the workspace shell", async ({ page }) => {
    await page.goto("/help");
    await expectAuthenticatedShell(page);
    await page.getByRole("link", { name: "Contact support" }).click();
    await expect(page).toHaveURL(/\/contact$/);
    await expectAuthenticatedShell(page);
    await expect(page.getByRole("heading", { name: "Contact us" })).toBeVisible();
  });

  test("app logo returns to Overview instead of the public landing page", async ({ page }) => {
    await page.goto("/help");
    await expectAuthenticatedShell(page);
    await openWorkspaceMenuIfNeeded(page);
    await page
      .getByRole("link", { name: /SaveStream/ })
      .first()
      .click();
    await expect(page).toHaveURL(/\/overview$/);
  });

  test("authenticated users are not shown sign-in or sign-up again", async ({ page }) => {
    await page.goto("/sign-in");
    await expect(page).toHaveURL(/\/(overview|admin\/system)$/);
    await page.goto("/sign-up");
    await expect(page).toHaveURL(/\/(overview|admin\/system)$/);
  });

  test("landing page recognizes an existing session", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("link", { name: "Open dashboard" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Sign in" })).toHaveCount(0);

    const mobileMenu = page.getByRole("button", { name: "Open menu" });
    if (await mobileMenu.isVisible()) {
      await mobileMenu.click();
    }
    await expect(page.getByRole("link", { name: "Buy credits" }).first()).toBeVisible();
  });

  test("Billing is easy to reach and does not trigger a purchase", async ({ page }) => {
    await page.goto("/overview");
    await page.getByRole("link", { name: "Buy credits" }).first().click();
    await expect(page).toHaveURL(/\/billing\/?$/);
    await expect(page.getByRole("heading", { name: "Billing" })).toBeVisible();
  });
});

test.describe("public and sign-in UX", () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test("email and password sign-in succeeds", async ({ page }, testInfo) => {
    const email = process.env.SAVESTREAM_E2E_EMAIL;
    const password = process.env.SAVESTREAM_E2E_PASSWORD;
    test.skip(
      testInfo.project.name !== "desktop-chromium" || !email || !password,
      "Run one real credential login per suite when production credentials are configured.",
    );

    await page.goto("/sign-in");
    await page.getByLabel("Email").fill(email);
    await page.locator("input#password").fill(password);
    await page.getByRole("button", { name: "Sign in" }).click();
    await expect(page).toHaveURL(/\/(overview|admin\/system)$/);
  });

  test("sign-in form uses consumer-friendly placeholders", async ({ page }) => {
    await page.goto("/sign-in");
    await expect.soft(page.getByLabel("Email")).toHaveAttribute("placeholder", "you@gmail.com");
    await expect.soft(page.locator("input#password")).toHaveAttribute("placeholder", "Password");
  });

  test("public pages load without client-side crashes", async ({ page }) => {
    const errors = collectClientErrors(page);

    for (const path of ["/", "/pricing", "/help", "/contact", "/terms", "/privacy", "/refund"]) {
      errors.length = 0;
      await page.goto(path);
      await expect(page.locator("body")).toBeVisible();
      expect(errors, `client errors on ${path}`).toEqual([]);
    }
  });
});
