# Fantasy Camera Flutter

A high-performance Flutter camera application ("TesserCam") demonstrating advanced integration with a local `camera_avfoundation` plugin and a backend-powered generation pipeline.

## Project Overview

- **Purpose:** A sophisticated camera app that leverages low-level AVFoundation capabilities for precise zoom control and dynamic range management. It integrates with a backend (via Supabase and Cloudflare Workers) for image generation and storage.
- **Key Technologies:**
  - **Framework:** Flutter (>= 3.38.0)
  - **State Management:** Riverpod (`flutter_riverpod`)
  - **Navigation:** GoRouter (`go_router`)
  - **Backend/Auth:** Supabase (`supabase_flutter`), Sign in with Apple
  - **Local Database:** Drift (`drift`) for structured local storage
  - **UI Design:** Cupertino (iOS-native look and feel)
  - **Camera:** Custom local package `camera_avfoundation`
- **Architecture:** Feature-first organization within `lib/features/`.
  - `lib/auth/`: Authentication logic and UI.
  - `lib/features/camera/`: Core camera interface and state management.
  - `lib/features/generation_submission/`: Submission to and gallery for the generation pipeline.
  - `lib/shared/`: Reusable core logic and UI components.

## Building and Running

### Prerequisites
- Flutter SDK (>= 3.38.0)
- iOS device (for camera functionality, as it relies on `camera_avfoundation`)

### Setup
1.  Install dependencies:
    ```bash
    flutter pub get
    ```
2.  Generate code (for Drift and other generated files):
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

### Execution
The app requires specific `dart-define` flags for full functionality.

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_KEY \
  --dart-define=WORKER_API_BASE_URL=YOUR_WORKER_API_URL
```

### Testing
- **Unit/Widget Tests:** `flutter test`
- **Integration Tests:** `flutter test integration_test/image_pipeline_device_test.dart`
- **E2E Tests:** Uses Maestro (`.maestro/auth_smoke.yaml`)

## Development Conventions

- **Architecture:** Follow the feature-first pattern. Each feature should contain its own `data`, `domain`, and `presentation` layers if applicable.
- **State Management:** Use Riverpod. Prefer `AsyncValue` for asynchronous state and providers for dependency injection.
- **Naming:** Follow standard Dart/Flutter naming conventions (PascalCase for classes, camelCase for variables/methods).
- **Configuration:** App-wide constants and environment-derived configuration are centralized in `lib/config/app_config.dart`.
- **Localization:** Use `.arb` files in `lib/l10n/`. Generate code with `flutter gen-l10n` (automated by `flutter: generate: true` in `pubspec.yaml`).
- **Linting:** Strictly adhere to the rules in `analysis_options.yaml` (includes `flutter_lints`).
- **Camera Handling:** Zoom logic is centralized in `cameraStateProvider` and follows specific raw-to-display multiplier logic as described in `README.md`.
- **Photo Processing:** Images are target-scaled to 2048px (max side) before upload, typically encoded as SDR HEIF to avoid HDR gain map complexities.
