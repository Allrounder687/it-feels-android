# AI Agents Log
This file tracks major technical decisions, features implemented, and architecture shifts guided by AI agents.

## Latest Agent Iteration
- **AV Handoff & Optimistic UI Architecture (Phase 5 - v3.5.19+53 Hotfix 2):**
  - **Instant Optimistic UI:** Shrank `PaletteGenerator` pixel sampling constraints to exactly 100x100 within `audio_player_provider.dart`. This dropped synchronous main thread blocking from ~1000ms down to ~2ms, ensuring route transitions are perfectly instant.
  - **Seamless AV Sync:** Introduced an `isBackgroundHandoff` engine to mutually `pause()` streaming buffers between Audio and Video tabs, rather than aggressively `closeVideo()`-ing them. This enabled millisecond-perfect cross-fading without re-fetching network URLs.
  - **Video Quality Lock:** Fixed the '2-attempts' bug by explicitly locking the new `selectedQuality` state *synchronously* during the bottom sheet interaction, and securely capturing the active buffer `startPosition` to resume the new quality without starting from 0:00.
  - **Lyrics Rolling Animation:** Rebuilt `_LiveLyricsPreviewCard` with an `AnimatedSwitcher` paired to a custom `SlideTransition` mapping, providing a 2026-era karaoke aesthetic featuring fading history and active highlighting.
  - **Accessibility Flood Fix:** Wrapped `WavySeekBar` inside `ExcludeSemantics` in `wavy_seek_bar.dart` to mitigate the `Failed to update ui::AXTree` exception spam on Windows triggered by 60fps slider redraws.
  - **AV Canvas Synchronization:** Hard-synced the background video engine to scrub to the exact millisecond (`seek()`) of the audio engine upon resuming playback, completely eliminating drifting. Forced `media_kit` volume to natively initialize at `0.0` when used as a background canvas to prevent dual-audio echoing.
  - **MiniPlayer State Machine:** Repaired a dual-vanishing bug where both the Video PiP and Audio MiniPlayer would hide themselves on the home screen when a visual canvas was active.
  - **Dynamic Home Hero Layout:** Stripped hardcoded height constraints from the `home_screen.dart` featured banner, allowing the `RenderFlex` to dynamically expand for ultra-long music video titles without throwing overflow exceptions.
- **Hero Tag Collision & UI Architecture (v3.5.19+53 Hotfix):** Removed nested `MiniPlayer` widgets from library screens (`ArtistDetailScreen`, `PlaylistDetailScreen`, etc.). Relying entirely on the global `MainNavigationWrapper` prevents dangerous `Hero` tag duplication crashes (`cover_saavn...`) from destroying the page route stack.
- **Audio Caching File Lock (errno 32) Fix (v3.5.19+53 Hotfix):** Swapped `LockCachingAudioSource` for `AudioSource.uri` for ephemeral YouTube/Piped streams to bypass writing temporary files to disk. Combined with `stop()` flush calls, this entirely mitigates Windows file locking stutter/crashing during concurrent AV pipeline switching.
- **Windows Exclusive Fullscreen (v3.5.19+53 Hotfix):** Implemented dynamic `TitleBarStyle.hidden` hooks in `video_player_screen.dart` that explicitly signal the Windows Desktop Window Manager to strip the non-client title bar during video fullscreen mode.
- **Video Player PiP & Trending Fixes (v3.5.16 Hotfix):**
  - **Video PiP:** Re-implemented `VideoMiniplayer` via `miniplayer` package, injected at the global `MainNavigationWrapper` level to enable picture-in-picture persistence across the entire app stack.
  - **Audio/Video Concurrency:** Rewrote provider playback logic (`audioPlayerProvider` & `videoPlayerProvider`) to mutually lock out and close competing media streams, resolving dual playback bugs.
  - **Trending Videos Resilience:** Replaced broken `FEtrending` InnerTube post request fallback with a `youtube_explode_dart` search extraction for guaranteed "trending music videos" rendering.
- **CI/CD iOS Shorebird Patch Fix & Social Testing (v3.5.16):**
  - **CI/CD Resiliency:** Fixed a silent failure in `shorebird_patch.yml` where iOS patches were skipped because they ran on `ubuntu-latest`. **CRITICAL RULE**: iOS patches *MUST* run on Apple hardware (`macos-latest`). Separated the pipeline into `patch-android` (ubuntu-latest) and `patch-ios` (macos-latest) jobs.
  - **Testing Architecture:** Refactored `SocialScreen` and `AudioPlayerNotifier` to decouple hardcoded `FirebaseFirestore.instance` and `FirebaseAuth.instance` calls. Injected them via `locator` to fully unblock Widget Test automation environments.
  - **Crash Fix:** Enhanced the Friends Tab to handle corrupted Firebase arrays securely, avoiding `ErrorWidget` crashes.
  - **Infinite Loading Fix:** Refactored the Friends Tab's list tile rendering to use a cached Riverpod `FutureProvider` instead of a standard `FutureBuilder`. This prevents continuous Future re-evaluations and infinite loading skeleton animations triggered by real-time presence or mini-player UI frame rebuilds.
  - **Version Bump:** Incremented version to `3.5.16+50`.
- **Search Pagination & DI Architecture Release (v3.5.15):**
  - **Search Enhancements:** Integrated pagination for songs, albums, and playlists, added video search capabilities, and allowed removal of individual recent search terms.
  - **Testing Architecture:** Refactored multiple services (`RadioApiService`, `SocialService`, `LastfmService`) to support Dependency Injection, unblocking comprehensive unit testing. Added `RoomService` and `SmartStorageService` to `GetIt` locator.
  - **Widget Teardown Fix:** Prevented state mutation exceptions during `VideoPlayerScreen` disposal by wrapping provider reads in `Future.microtask`.
  - **CI & Settings Resiliency:** Hid critical proxy settings behind "Advanced Server Settings" warnings to prevent accidental stream breakages. Fixed Shorebird and FilePicker compilation errors in CI.
  - **Version Bump:** Incremented version to `3.5.15+49`.

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
- **Shorebird Patching Protocol:** When the user requests a silent patch (triggered by pushing a `patch-v*` tag), you MUST NOT bump the `version` in `pubspec.yaml`. Shorebird patches ONLY support Dart code changes and must target the exact version string of an existing baseline release. If your changes include native plugin additions (e.g. C++ binaries, iOS pods, Android gradle edits), a patch will fail. In that scenario, or if you bump the `pubspec.yaml` version, you MUST trigger a full OTA release (`v*` tag) instead.
- **Version Management:** Do NOT bump `pubspec.yaml` `version` for small hotfixes/edits unless you intend to push a global OTA update. Only bump `pubspec.yaml` for major feature releases or major milestones. For small updates and bug fixes, document changes directly under the current version section in `CHANGELOG.md`.
- **Responsive & Edge-to-Edge Design:** ALWAYS wrap top-level layout boundaries or floating widgets in `SafeArea` to respect system insets (notches, status bars, and navigation pills). NEVER hardcode fixed heights/widths for containers meant to fill the screen; instead use `Expanded`, `Flexible`, `LayoutBuilder`, or relative `MediaQuery.of(context).size` values to guarantee flawless adaptation across all Android form factors.
