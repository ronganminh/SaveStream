import {
  Outlet,
  createHashHistory,
  createRootRoute,
  createRoute,
  createRouter,
} from "@tanstack/react-router";
import {
  AdminErrorsPage,
  AdminJobDetailPage,
  AdminJobsPage,
  AdminSystemPage,
  AdminWorkersPage,
  AuthPage,
  BillingPage,
  ChannelDetailPage,
  ChannelsPage,
  HelpPage,
  LandingPage,
  LegalPage,
  NotificationsPage,
  OnboardingPage,
  OverviewPage,
  PricingPage,
  RecordingDetailPage,
  RecordingsPage,
  SettingsPage,
  StatusPage,
  UsagePage,
  VerifyEmailPage,
} from "./pages";

const rootRoute = createRootRoute({ component: () => <Outlet /> });

const route = <const TPath extends string,>(
  path: TPath,
  component: () => React.ReactNode,
) => createRoute({ getParentRoute: () => rootRoute, path, component });

const indexRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: LandingPage });
const pricingRoute = route("/pricing", PricingPage);
const signInRoute = route("/sign-in", () => <AuthPage mode="sign-in" />);
const signUpRoute = route("/sign-up", () => <AuthPage mode="sign-up" />);
const forgotRoute = route("/forgot-password", () => <AuthPage mode="forgot" />);
const resetRoute = route("/reset-password", () => <AuthPage mode="reset" />);
const verifyRoute = route("/verify-email", VerifyEmailPage);
const onboardingRoute = route("/onboarding", OnboardingPage);
const overviewRoute = route("/overview", OverviewPage);
const channelsRoute = route("/channels", ChannelsPage);
const channelRoute = createRoute({ getParentRoute: () => rootRoute, path: "/channels/$channelId", component: ChannelRoute });
function ChannelRoute() { const { channelId } = channelRoute.useParams(); return <ChannelDetailPage channelId={channelId} />; }
const recordingsRoute = route("/recordings", RecordingsPage);
const recordingRoute = createRoute({ getParentRoute: () => rootRoute, path: "/recordings/$recordingId", component: RecordingRoute });
function RecordingRoute() { const { recordingId } = recordingRoute.useParams(); return <RecordingDetailPage recordingId={recordingId} />; }
const activeRoute = route("/recordings/active", () => <RecordingDetailPage state="active" />);
const processingRoute = route("/recordings/processing", () => <RecordingDetailPage state="processing" />);
const failedRoute = route("/recordings/failed", () => <RecordingDetailPage state="failed" />);
const usageRoute = route("/usage", UsagePage);
const billingRoute = route("/billing", BillingPage);
const settingsRoute = route("/settings", SettingsPage);
const notificationsRoute = route("/notifications", NotificationsPage);
const helpRoute = route("/help", HelpPage);
const statusRoute = route("/status", StatusPage);
const termsRoute = route("/terms", () => <LegalPage title="Terms of Service" />);
const privacyRoute = route("/privacy", () => <LegalPage title="Privacy Policy" />);
const acceptableUseRoute = route("/acceptable-use", () => <LegalPage title="Acceptable Use Policy" />);
const adminSystemRoute = route("/admin/system", AdminSystemPage);
const adminWorkersRoute = route("/admin/workers", AdminWorkersPage);
const adminJobsRoute = route("/admin/jobs", AdminJobsPage);
const adminJobRoute = createRoute({ getParentRoute: () => rootRoute, path: "/admin/jobs/$jobId", component: AdminJobRoute });
function AdminJobRoute() { const { jobId } = adminJobRoute.useParams(); return <AdminJobDetailPage jobId={jobId} />; }
const adminErrorsRoute = route("/admin/errors", AdminErrorsPage);

const routeTree = rootRoute.addChildren([
  indexRoute, pricingRoute, signInRoute, signUpRoute, forgotRoute, resetRoute, verifyRoute,
  onboardingRoute, overviewRoute, channelsRoute, channelRoute, recordingsRoute, recordingRoute,
  activeRoute, processingRoute, failedRoute, usageRoute, billingRoute, settingsRoute,
  notificationsRoute, helpRoute, statusRoute, termsRoute, privacyRoute, acceptableUseRoute,
  adminSystemRoute, adminWorkersRoute, adminJobsRoute, adminJobRoute, adminErrorsRoute,
]);

export const router = createRouter({
  routeTree,
  history: createHashHistory(),
  defaultPreload: "intent",
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
