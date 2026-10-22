# Android v2 — System screens

App screenshots are rendered by `apps/mobile/test/screenshots/system_screens_test.dart` (real
widgets and router, bundled Plus Jakarta Sans, 390×844 at 2×) with a fake `GET /v1/app/status` and
connectivity. Artboard renders come from the design's `<name>.dc.html` files in headless Chromium
at the same size.

Regenerate the app PNGs from `apps/mobile`:

```sh
SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/system flutter test test/screenshots/system_screens_test.dart
```

On CI the Android emulator job also renders these screens
(`integration_test/system_screenshots_test.dart`) and compares them with this folder.

| Screen | App | Artboard |
| --- | --- | --- |
| AOffline | [AOffline.png](AOffline.png) | [AOffline.artboard.png](AOffline.artboard.png) |
| AServerError | [AServerError.png](AServerError.png) | [AServerError.artboard.png](AServerError.artboard.png) |
| AMaintenance | [AMaintenance.png](AMaintenance.png) | [AMaintenance.artboard.png](AMaintenance.artboard.png) |
| AForceUpdate | [AForceUpdate.png](AForceUpdate.png) | [AForceUpdate.artboard.png](AForceUpdate.artboard.png) |

ASuspended and ATerminated are in `../account` (they follow a refused sign-in).

## How they are triggered

The signed-in shell (`MainShell`) shows them full screen, most blocking first, replacing the v1
"update required / maintenance" page and the offline banner:

- **Update required**: `GET /v1/app/status` `min_supported_version.android` is above the installed
  version (`package_info_plus`; before, a build-time define that release builds never set). "Update on
  Google Play" opens `market://details?id=com.savestream.app`, else the Play web listing. Shows
  "Installed x · required y".
- **Maintenance**: `maintenance.active`. The ETA (`maintenance.eta`) is shown in UTC (time only when
  it is today, else date and time). "Check status" opens savestream.online/status; "Try again"
  asks again.
- **Server error**: the status request failed with a 5xx. The failed request's `X-Request-ID` is the
  "Error ID". Retry asks again; "Contact support" opens a mail to support with the id.
- **No connection**: the connectivity service reports offline (the same source as before). "Try
  again" re-checks the connection and the status; when the connection returns on its own the app
  comes back with the "Back online" toast. A status request that fails for network reasons does not
  block the app.

## Intentional differences

**Maintenance.** Without an ETA the body is "We’re upgrading SaveStream. Recordings already saved are
safe." (not drawn).

**Server error.** Without a request id the Error ID line is hidden. The screen covers only a failed
status check; other failed requests keep their in-screen error states.
