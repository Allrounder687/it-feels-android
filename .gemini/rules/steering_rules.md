# IT Feels Music - AI Agent Rules

These rules MUST be followed by all AI agents at all times, without exception, for the IT Feels Music project.

## 1. Development & Testing Workflow (Zero Exceptions)
- **Test-Driven Growth**: Every new feature or bug fix must be accompanied by comprehensive tests. You must write new widget or unit tests for any new UI components or logic you create.
- **Verification**: Run `flutter analyze` and `flutter test` and ensure all tests pass before proposing or committing changes. Ensure zero unhandled exceptions on network or playback failures.
- **Documentation**: You MUST update `README.md`, `CHANGELOG.md`, and any relevant `.gemini/skills/` files with detailed explanations of your changes before committing.

## 2. Release & Patch Management (Shorebird)
- **CI/CD OTA Release Protocol**: Do NOT use the `deploy_ota.bat` script. When completing a major milestone, manually bump the `version` in `pubspec.yaml`, commit, and create/push a Git tag (e.g., `v3.3.0`) via the CLI to trigger GitHub Actions.
- **Version Management**: Do NOT bump `pubspec.yaml` `version` for small hotfixes/edits. Only bump it for major feature releases.
- **Native code, Assets, or Flutter Upgrades**: Require a full binary release (OTA).
- **Dart code only**: Can be patched OTA. Use `shorebird patch [platform]`. Note that iOS patches MUST run on macOS hardware.
- **CRITICAL**: A `shorebird patch` MUST target an *existing* `shorebird release`. If you bump the app version in `pubspec.yaml`, the previous release no longer matches. You **cannot patch a new version that hasn't been released yet**. Do NOT bump versions unless explicitly creating a new Release. Do NOT use `deploy_ota.bat`.

## 3. API & Backend Integration
- **Cloudflare Proxy & Security**: Route multi-source searches, lyrics fetching, and stream resolution through the Cloudflare Worker proxy (`BackendApiService.baseUrl`). ALWAYS include the `X-Feels-Secret` header.
- **Audio & Data**: Ensure 320kbps AAC/MP4 quality resolution. Handle DES-ECB link decryption safely with direct client fallback mode.
- **Content Filtering**: Manage aggressive content filtering (`_isBhakti`) to keep popular playlists free of devotional tracks.
- **DatabaseService**: Ensure Isar metadata fields like `playCount` and `searchVector` are generated correctly when saving models.

## 4. Architecture & UI Guidelines
- **Zero Cognitive Overload UX**: Ensure graceful empty states, smooth animations, and intuitive interactions following Material 3 Expressive UI guidelines. Do not leave empty UI elements without a placeholder.
- **Decoupling Logic**: Keep business logic out of UI files. Use `Notifier` or `StateNotifier` for Riverpod to bridge UI and services. No direct `locator<Service>()` calls should happen in widget `build()` or `onPressed()` methods.
- **Custom Rendering**: Implement custom canvas painters (e.g. `WavySeekBar`, `HeroCollagePainter`) with sub-pixel alignment and smooth performance.
- **UI Padding**: Use `AppDimensions.bottomClearance` for standardizing padding across all UI screens (especially above bottom navigation bars or media players) instead of raw padding values.
- **Responsiveness**: Use `Expanded`, `Flexible`, `LayoutBuilder`, `MediaQuery.of(context).size` for responsive layouts. Avoid hardcoded sizes. Always wrap top-level layout boundaries in `SafeArea`.
