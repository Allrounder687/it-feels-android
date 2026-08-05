# IT Feels Music - AI Agent Rules

These rules MUST be followed by all AI agents at all times, without exception, for the IT Feels Music project.

## 1. Development & Testing Workflow (Zero Exceptions)
- **Test-Driven Growth**: Every new feature or bug fix must be accompanied by comprehensive tests. You must write new widget or unit tests for any new UI components or logic you create.
- **Verification**: Run `flutter analyze` and `flutter test` and ensure all tests pass before proposing or committing changes.
- **Documentation**: You MUST update `CHANGELOG.md` with detailed explanations of your changes before committing.

## 2. Release & Patch Management (Shorebird)
- **Native code, Assets, or Flutter Upgrades**: Require a full binary release. Use `shorebird release [platform]` (or bump `pubspec.yaml` version and push to trigger CI release).
- **Dart code only**: Can be patched OTA. Use `shorebird patch [platform]`.
- **CRITICAL**: A `shorebird patch` MUST target an *existing* `shorebird release`. If you bump the app version in `pubspec.yaml`, the previous release no longer matches. You **cannot patch a new version that hasn't been released yet**. Do NOT bump versions unless explicitly creating a new Release. Do NOT use `deploy_ota.bat`.

## 3. Architecture & UI Guidelines
- **Zero Cognitive Overload UX**: Ensure graceful empty states, smooth animations, and intuitive interactions. Do not leave empty UI elements without a placeholder.
- **Decoupling Logic**: Keep business logic out of UI files. Use `Notifier` or `StateNotifier` for Riverpod to bridge UI and services. No direct `locator<Service>()` calls should happen in widget `build()` or `onPressed()` methods.
- **UI Padding**: Use `AppDimensions.bottomClearance` for standardizing padding across all UI screens (especially above bottom navigation bars or media players) instead of raw padding values.
- **Responsiveness**: Use `Expanded`, `Flexible`, `LayoutBuilder`, `MediaQuery.of(context).size` for responsive layouts. Avoid hardcoded sizes. Always wrap top-level layout boundaries in `SafeArea`.
