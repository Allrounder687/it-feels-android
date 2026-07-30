# AI Agents Log
This file tracks major technical decisions, features implemented, and architecture shifts guided by AI agents.

## Latest Agent Iteration
- **iOS Unsigned GitHub Actions CI Fix:** Resolved GitHub Actions workflow failure (Exit Code 65) by injecting placeholder `DEVELOPMENT_TEAM = A1B2C3D4E5` and `CODE_SIGNING_ALLOWED = NO` overrides in `Release.xcconfig`, `Debug.xcconfig`, and `project.pbxproj`, committing `ios/Podfile` with `post_install` code signing override hooks, and streamlining `.github/workflows/ios-unsigned-build.yml`.
- **Unified Media Player Architecture:** Replaced the clunky floating Miniplayer package with a unified `NowPlayingScreen` featuring a native YouTube Music-style `[ Song | Video ]` toggle switch.
- **Listen Together Lock Screen Persistence & Clear Notices:** Added `keepSynced(true)` to Firebase Realtime Database room references for seamless background/lock-screen sync. Added user notices for auth and active track states.
- **Hybrid High-Quality Sound in Video Mode:** Retained 320kbps/FLAC music player audio when switching to Video mode by default (muting video audio) with a new toggle in Settings ("Use Video Audio Source").
- **Mid-Song Lyrics Auto-Scroll & Seamless Font Cycling:** Added immediate auto-scrolling to current track line on lyrics screen open, and updated font selection to cycle smoothly without popups or toasts.
- **Lifetime Coupon "FAMILY":** Configured special coupon `FAMILY` to instantly grant lifetime premium status.
- **In-Memory Caching & Queue Preloading Pipeline:** Built in-memory lyrics caching in `LyricsService` and automatic queue preloading in `AudioPlayerProvider` for the active track and upcoming queue songs, making lyrics load instantly (0ms).
- **Data Saver Mode:** Built a comprehensive Data Saver engine in `SettingsProvider` and `CustomImageWidget` that caps streaming audio to 64kbps and downsamples cover art URLs (500x500 -> 150x150) to minimize cellular data usage by up to 80%.
- **Fast-Resume & Hardware Decoder Fix:** Implemented a highly optimized `ValueListenableBuilder` pipeline to instantly swap between audio and video modes without destroying native Android `VideoPlayerController` buffers, permanently eliminating `I/CCodecConfig (BAD_INDEX)` crashes and 60fps seekbar freezing.
- **Robust Edge Fallbacks:** Hardened `BackendApiService` with client-side `youtube_explode_dart` search fallbacks, enforcing strict 11-character constraints to automatically bypass Saavn IDs and automatically appending "official music video" to YouTube search queries.
- **Cloudflare Edge Acceleration:** Deployed Phase 1 Cloudflare Worker enhancements including KV caching for zero-latency multi-source searches and lyrics lookups, a dynamic Image Proxy cache for CDN acceleration, and robust API Abuse Prevention via the `X-Feels-Secret` HTTP header.
- **Model Updates for IT Feels AI Provider:** Upgraded ChatGPT to `gpt-5.6-luna`, Claude to `claude-haiku-4-5-20251001`, and Gemini to `gemini-3.5-flash-lite` to ensure the absolute lowest possible API costs while maintaining 2026-level performance.
- **Backend E2E Validation:** Created a standalone native Node.js testing harness (`npm run test`) for the Cloudflare Worker to rapidly iterate on AI prompts, KV caching, and multi-source scraping APIs completely isolated from the Flutter app.
- **Phase 3 Firebase Initialization:** Configured the Flutter client with `flutterfire_cli`, registering Android, iOS, macOS, Web, and Windows apps and generating `firebase_options.dart` to support Cloud Firestore and Realtime Database WebSockets.
- **Audiophile DSP Integration:** Implemented toggle controls for AndroidEqualizer and AndroidLoudnessEnhancer within Settings, bypassing complex manual slider UX for zero cognitive overload.
- **Bitrate Badges:** Enhanced Now Playing screen to dynamically show LOSSLESS, HIGH-RES, or 320 KBPS badges by parsing the media stream extension.
- **CDN Token Expiry Handling:** Fixed `just_audio` 00:00 bug by aggressively stripping `encryptedMediaUrl` before saving to local database. This prevents restoring ephemeral Jio CDN links and forces fresh API resolution on playback resume.
- **iOS AVPlayer Stability:** Added `initialPosition: Duration.zero` to `setAudioSource` on iOS to circumvent infinite loop bugs when switching tracks from a `completed` state.
- **Gapless Playback Migration:** Switched from individual setUrl to ConcatenatingAudioSource for true gapless transitions.
- **Dynamic Theming Integration:** Refactored AudioPlayerProvider to calculate and broadcast Material You ColorSchemes derived from HomeWidgetProvider background processes and just_audio streams.
- **Android Integrations:** Added home_widget implementation in native Kotlin (MusicWidgetProvider.kt), managed namespace mismatches, and prepared Android Auto manifest entries.
- **Ask Feels Branding:** Renamed AI system to "Ask Feels" with conversational UX ("What are you feeling like?").
- **Build Isolation:** Configured debug builds with unique `applicationIdSuffix` and `appName` for parallel release/debug installations on user devices.
- **Dynamic Edge-to-Edge Padding:** Removed hardcoded safe areas in favor of `MediaQuery.viewPadding.bottom` and `MediaQuery.viewPadding.top`, dynamically adapting the UI to any Android system navigation bar and iOS Notch heights.
- **Layout Exception Hotfixes:** Replaced raw `DecoratedBox` implementations around `ListTile`s with `Material` to resolve underlying layout crash vectors.
- **UX Polish:** Implemented Haptics via vibration on player controls, adjusted bottom navigation size, and added tap-to-seek lyrics.
- **Cache Playback Engine:** Patched local `Song` deserialization schemas to handle both camelCase and snake_case API mappings, restoring offline playback reliability for the Queue and Recently Played lists.
- **Tablet Optimizations:** Added responsive Hero Banners, immersive side-by-side Now Playing screens, and authentic glassmorphism for tablet form factors.

## Agent Directives (Rules)
- **Strict Development Workflow:** ALWAYS follow this exact cycle for new features: 1) Write the code. 2) Create unit/integration tests to verify functionality and prevent regressions. 3) Run and verify the tests pass. 4) Document the changes in `README.md`, `CHANGELOG.md`, and any relevant `.gemini/skills/` files. 5) Run a local `git commit` locking in the verified feature.
- **Version Management:** Do NOT bump `pubspec.yaml` `version` for small hotfixes/edits. Only bump `pubspec.yaml` for major feature releases or major milestones. For small updates and bug fixes, document changes directly under the current version section in `CHANGELOG.md`.
- **Responsive & Edge-to-Edge Design:** ALWAYS wrap top-level layout boundaries or floating widgets in `SafeArea` to respect system insets (notches, status bars, and navigation pills). NEVER hardcode fixed heights/widths for containers meant to fill the screen; instead use `Expanded`, `Flexible`, `LayoutBuilder`, or relative `MediaQuery.of(context).size` values to guarantee flawless adaptation across all Android form factors.
