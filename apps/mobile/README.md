# SaveStream Mobile

Flutter mobile client for SaveStream.

## Current milestone

Phase 1 includes:

- SaveStream semantic design tokens;
- Material 3 Light / Dark / System themes;
- English and Vietnamese localization with Flutter gen_l10n;
- reusable buttons, fields, cards, status chips, states, dialogs, and feedback;
- a temporary component gallery for visual QA.

The component gallery will be replaced by the app shell in Phase 2.

## Requirements

- Flutter 3.47.0 stable for CI parity.
- Dart bundled with Flutter.

## Run locally

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter run
```

Local environment defaults to:

```text
APP_ENV=local
API_BASE_URL=http://10.0.2.2:8000
```

Override build configuration with Dart defines:

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://api-staging.example.com
```

## Validation

```bash
flutter gen-l10n
dart format --output=none --set-exit-if-changed \
  lib/app lib/core lib/features lib/l10n/l10n.dart test
flutter analyze --fatal-infos
flutter test
```

CI runs the same checks on `feat/flutter-mobile`.
