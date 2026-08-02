# AI Agents Log
This file tracks major technical decisions, features implemented, and architecture shifts guided by AI agents. For detailed guidelines on agent operation, refer to [STEERING_PATH.md](STEERING_PATH.md).

## Latest Agent Iteration
- **Agent Steering & Infrastructure Updates (2026-08-02):**
  1. **Unified Agent Steering Path:** Formulated `STEERING_PATH.md` to establish coding standards, responsive design practices, and operational paradigms for subsequent AI agents.
  2. **Agent Role Refinements:** Refined specifications for `tester_verifier`, `ui_builder`, and `api_integrator` agents to align with `STEERING_PATH.md`.
  3. **New Agent Skills Integration:** Developed `doc-writer-skill` for automated documentation outlining, summary writing, and changelog updates. Integrated this skill as a directive for the `tester_verifier` agent.

- **Social Tab Crash Hotfix (v3.5.12):**
  - **Syntax Fix**: Resolved syntax errors and StreamBuilder type mismatches introduced in the previous hotfix.
  - **Crash Fix**: Resolved a critical layout exception in the Social Tab caused by Firebase Realtime Database occasionally returning lists instead of maps. Wrapped items and type casts in `try-catch` blocks to prevent the `TabBarView` from rendering the ErrorWidget (a blank grey screen).
  - **Version Bump:** Incremented version to `3.5.12+45`.

- **Social Enhancements & Player Fixes Release (v3.5.9 / v3.5.10):**
  - **Modern Chat Bubbles**: Revamped the Social Inbox to use native iMessage-like gradient chat bubbles.
  - **Active Rooms Carousel**: Integrated a global carousel in the Friends tab to display active Listen Together rooms, filtering for public rooms hosted by premium users.
  - **Friend Profiles**: Added interactive profiles accessible via the friends list, allowing users to view and import public playlists.
  - **Player & Sync Fixes**: Fixed infinite loading in playlist sharing, restored LRCLIB sync accuracy by replacing post-frame callbacks with Riverpod listeners, and resolved the sticky video glow bug.
  - **Version Bump:** Incremented version to `3.5.9+41`.

- **Account Entitlement, Isar Multi-Isolate & Firebase Resiliency Release (v3.5.8):**
  - **Account-Bound Entitlements**: Bound premium status strictly to authenticated user IDs in Firestore (`/users/<uid>`), isolating guests and secondary accounts.
  - **Isar Multi-Isolate & Hot Restart Safety**: Added 200ms fallback retry and isolate detection in `DatabaseService` to prevent `Collection id is invalid` crashes during background isolate startup or Flutter Hot Restart.
  - **Firebase Auth Error Guards**: Handled `admin-restricted-operation` and `too-many-requests` gracefully; bound app language via `FirebaseAuth.instance.setLanguageCode('en')`.
  - **Piped Stream Resolution Cleanup**: Pruned dead Piped API mirrors, lowered connection timeout to 2.5s, and silenced verbose failover logs.
  - **iOS Swift Package Manager (SPM) Platform Version Fix**: Mitigated an issue where Flutter 3.24+ hardcodes SPM templates to iOS 13.0 causing exit code 65 due to modern Firebase and background_downloader requirements. Dynamically patched the Flutter SDK's internal SPM generator using `sed` to force iOS 15.0 target deployment in CI environment.
  - **Version Bump:** Incremented version to `3.5.8+40`.

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
- **CI/CD OTA Release Protocol:** Do NOT use the `deploy_ota.bat` script. When completing a major milestone or when the user explicitly requests an app update release, you MUST manually bump the `version` in `pubspec.yaml` (e.g., `3.3.0+10`), commit the change, and then manually create and push the Git tag (e.g., `v3.3.0` for both platforms, or `ios-v3.3.0` / `android-v3.3.0` for specific platforms) via the CLI. This triggers the GitHub Actions CI/CD pipeline which builds the release and silently injects the new version details directly into Firestore (`client_config`) for global OTA distribution.
- **Version Management:** Do NOT bump `pubspec.yaml` `version` for small hotfixes/edits unless you intend to push a global OTA update. Only bump `pubspec.yaml` for major feature releases or major milestones. For small updates and bug fixes, document changes directly under the current version section in `CHANGELOG.md`.
- **Responsive & Edge-to-Edge Design:** ALWAYS wrap top-level layout boundaries or floating widgets in `SafeArea` to respect system insets (notches, status bars, and navigation pills). NEVER hardcode fixed heights/widths for containers meant to fill the screen; instead use `Expanded`, `Flexible`, `LayoutBuilder`, or relative `MediaQuery.of(context).size` values to guarantee flawless adaptation across all Android form factors.
