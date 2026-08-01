# AI Agents Log
This file tracks major technical decisions, features implemented, and architecture shifts guided by AI agents.

## Latest Agent Iteration
- **CI/CD Resiliency & Fallback Release (v3.5.7):**
  - **Shorebird Build Fallback:** Added graceful fallbacks (`shorebird release ... || flutter build ...`) in both `ota_release.yml` and `ios-unsigned-build.yml` to prevent pipeline failures when releasing code with existing Shorebird versions.
  - **Version Bump:** Incremented version to `3.5.7+39`.

- **Admin Telemetry & Live Social Expansion (v3.2.0):** 
  1. **Concurrent Lyrics Racing:** Overhauled `LyricsService` from a slow sequential waterfall to a concurrent `Completer` race against 3 API sources, resolving lyrics in under a second.
  2. **Admin Filters & Dashboards:** Converted dashboard to stateful UI with offline local search filters (ChoiceChips) for heavy traffic.
  3. **Global Broadcasts & Reactive Promos:** Built `InAppBroadcastListener` to blanket the app in real-time snackbars triggered from the dashboard. Wired the Firebase stream to instantly trigger Confetti celebrations on remote Premium upgrades.
  4. **Force Update OTA Engine:** Built `ConfigService` and `ForceUpdateScreen` blocking users based on Firebase `min_version_code` mapping to `package_info_plus`.
  5. **Live Listening Parties:** Finalized real-time synced rooms. Locked hosting logic behind `subscriptionProvider` while permitting free-tier entry.

- **Strict Development Workflow:** ALWAYS follow this exact cycle for new features: 1) Write the code. 2) Create unit/integration tests to verify functionality and prevent regressions. 3) Run and verify the tests pass. 4) Document the changes in `README.md`, `CHANGELOG.md`, and any relevant `.gemini/skills/` files. 5) Run a local `git commit` locking in the verified feature.
- **CI/CD OTA Release Protocol:** When completing a major milestone or when the user explicitly requests an app update release, you MUST bump the `version` in `pubspec.yaml` (e.g., `3.3.0+10`) and run `deploy_ota.bat`. This automatically pushes the `v3.3.0` Git tag, triggering the GitHub Actions CI/CD pipeline which builds the release APK and silently injects the new version details directly into Firestore (`client_config`) for global OTA distribution.
- **Version Management:** Do NOT bump `pubspec.yaml` `version` for small hotfixes/edits unless you intend to push a global OTA update. Only bump `pubspec.yaml` for major feature releases or major milestones. For small updates and bug fixes, document changes directly under the current version section in `CHANGELOG.md`.
- **Responsive & Edge-to-Edge Design:** ALWAYS wrap top-level layout boundaries or floating widgets in `SafeArea` to respect system insets (notches, status bars, and navigation pills). NEVER hardcode fixed heights/widths for containers meant to fill the screen; instead use `Expanded`, `Flexible`, `LayoutBuilder`, or relative `MediaQuery.of(context).size` values to guarantee flawless adaptation across all Android form factors.
