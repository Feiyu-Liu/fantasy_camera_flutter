# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Code generation (Drift DB + localization)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app (dart-define flags required for backend features)
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_KEY \
  --dart-define=WORKER_API_BASE_URL=YOUR_WORKER_API_URL

# Tests
flutter test                                                          # unit/widget
flutter test integration_test/image_pipeline_device_test.dart        # integration
# E2E via Maestro: .maestro/auth_smoke.yaml

# Lint
flutter analyze
```

Run `build_runner` whenever modifying `generation_record_database.dart` (Drift) or `.arb` localization files.

## Architecture

Feature-first layout under `lib/`. Each feature has `data/`, `domain/`, and `presentation/` layers where applicable.

```
lib/
├── main.dart                          # App bootstrap: orientation lock, SharedPrefs, BackgroundDownloader, Supabase init
├── app/app_router.dart               # GoRouter: /, /generation-gallery, /settings, /credits/purchase
├── config/app_config.dart            # All dart-define env vars; gated by AppConfig.hasSupabaseConfig
├── auth/                              # Supabase + Apple + Google auth; AuthGate is the root route
├── billing/                           # RevenueCat in-app purchases
├── features/
│   ├── camera/                        # AVFoundation camera; zoom logic lives in cameraStateProvider
│   ├── generation_submission/         # Full image generation pipeline: capture → upload → poll → gallery
│   ├── backend_api/                   # Cloudflare Worker API client + prompt config
│   └── notifications/                 # Push notification handling and navigation delegation
├── shared/                            # AppLogger, shared camera widgets, reusable UI components
├── settings/                          # App settings persisted via SharedPreferences
└── l10n/                             # .arb source files (en, zh); generated output in l10n/generated/
```

**State management:** Riverpod throughout. Use `AsyncValue` for async state; providers act as the DI layer. `AutoDispose` variants are standard for screen-scoped state.

**Local database:** Drift (`generation_record_database.dart`) tracks the full generation record lifecycle — from original image capture through upload, task polling, result caching, and user feedback. Schema changes require re-running `build_runner`.

**Camera zoom:** Raw AVFoundation zoom values map to display zoom via `displayZoomFactorMultiplier`. All zoom logic is centralized in `cameraStateProvider` — do not duplicate it.

**Photo processing:** Scale to 2048px max side, encode as SDR HEIF before upload to avoid HDR gain map issues. See `generation_image_processor.dart`.

**Navigation:** All routes use `CupertinoPage` for iOS-native transitions. The `generationGalleryRoute` accepts an optional `taskId` query param for deep-linking to a specific generation result.

**Localization:** Add/edit strings in `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`. Access via `AppLocalizations.of(context)`.

**Configuration:** Centralize all environment-derived values in `lib/config/app_config.dart`. Never scatter `dart-define` reads across the codebase.
