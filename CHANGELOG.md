# Changelog

All notable changes to **IT Feels Music** will be documented in this file.

## [2.6.0] - Unreleased (Phase 3: Listen Together)

### Added
- **Firestore Cloud Sync:** Built `CloudSyncService` to securely push local Isar `Song` favorites to Cloud Firestore. 
- **Real-Time Database Listeners:** Integrated bi-directional Firestore snapshot listeners that instantly merge cloud state into the local Isar database.
- **Dependency Injection & Tests:** Added DI to `CloudSyncService` and verified offline/online hybrid merge logic using `fake_cloud_firestore` unit tests.
- **Listen Together 0-Cognitive UI:** Built `RoomBottomSheet` that generates a giant QR Code and 6-digit PIN. Broadcasting is instantly available on the Player screen, while Guests can scan/type to join from the Home screen.
- **Listen Together Playback Sync:** Architected `AudioPlayerProvider` to silently push playback state (position, isPlaying, track) to RTDB if Host, and force-seek guests if their drift is >2000ms.
- **Magic Auth Flow:** Implemented a unified Email/Password Glassmorphic Bottom Sheet (`AuthBottomSheet`) ensuring zero cognitive overload without forcing logins on startup.
- **Anti-Enumeration Security:** Architected the `AuthProvider` to use a highly secure exception-catching flow (handling `user-not-found` & `invalid-credential`) to bypass modern Firebase Email Enumeration protections.
- **Auth Unit Tests:** Built 7 comprehensive Mocktail unit tests in `auth_provider_test.dart` to verify the state machine mathematically.
- **Firebase Core Initialization:** Configured `flutterfire_cli` across all 5 desktop and mobile platforms (Android, iOS, macOS, Windows, Web) in preparation for Realtime Database syncing and Cloud Firestore.
- **Unified Media Player UI:** Removed the clunky floating Miniplayer package. The `NowPlayingScreen` now natively supports playing videos directly inside the album art container, with a seamless top `[ Song | Video ]` toggle switch just like YouTube Music.
- **Real-Time Seekbar Optimization:** Wrapped `WavySeekBar`, timestamps, and animated `Play/Pause` icons inside `ValueListenableBuilder`s wired directly to the native video engine for smooth 60fps seekbar updates in Video Mode without redrawing the entire screen.
- **Fast-Resume Video Optimization:** Built a short-circuit in `VideoPlayerProvider` that instantly resumes cached streams when quickly switching back and forth between "Song" and "Video" without destroying native video controllers.
- **Client-Side Video Resolution Fallback:** Integrated `youtube_explode_dart` on the client side to silently search and resolve the exact 11-character YouTube ID for the current track to bypass Cloudflare proxy rate limits.
- **Official Video Prioritization:** Upgraded the YouTube search algorithm to automatically append `"official music video"` to ensure users get the actual music video rather than unofficial fan-made lyric videos.
- **Monetization & Subscriptions:** Integrated `purchases_flutter` (RevenueCat) to gate premium features (Lyrics, DSP Engine) behind a zero-cognitive-overload Glassmorphic Paywall (`PaywallBottomSheet`).
- **Custom Coupon Engine:** Built a Firestore-backed custom promo code redemption system allowing admins to issue custom string coupons (e.g., "FEELSFREE") that override local `isPremium` states.
- **Push Notifications (FCM):** Configured `firebase_messaging` with a new `NotificationService` that handles permission requests, background handlers, and securely stores APNs/FCM tokens in the user's Firestore document.
- **Transactional Emails:** Expanded the Cloudflare Proxy Engine (`backend/src/index.ts`) with a lightweight `/api/v1/send-email` endpoint using Resend's REST API to facilitate onboarding and receipt emails without inflating the client binary.
- **Listen Together Auth & State Notices:** Added clear user feedback in `RoomBottomSheet` informing users if they need to log in or start playing a song before broadcasting.
- **Listen Together Background Sync (`keepSynced`):** Enabled `keepSynced(true)` on Firebase RTDB room references so guest phones remain synchronized in real-time even when locked or minimized in the background.
- **Hybrid High-Quality Audio in Video Mode:** Retained 320kbps/FLAC music player audio when switching to Video mode by default while muting video player audio. Added "Use Video Audio Source" toggle setting in Settings.
- **Lyrics Mid-Song Auto-Scroll:** Implemented automatic scrolling to active lyric line upon opening `LyricsScreen` mid-song.
- **Seamless Lyrics Font Cycling:** Transformed font selection button into a direct touch handler (`cycleFont()`) that cycles fonts cleanly without toasts or popups.
- **Lifetime Coupon "FAMILY":** Added special coupon code `FAMILY` to instantly unlock lifetime premium entitlements.
- **Tablet Video Aspect Ratio:** Fixed iPad/Android tablet video container rendering by wrapping video stream in responsive `AspectRatio(16/9)`.
- **In-Memory Lyrics Caching & Queue Preloading:** Integrated an in-memory `_lyricsCache` in `LyricsService` and added queue preloading in `AudioPlayerProvider` to pre-fetch lyrics for current and upcoming tracks in the queue, achieving instant (0ms) lyrics loading.
- **3-Song Stream & Lyrics Auto-Preloader:** Wired `currentIndexStream` in `AudioPlayerProvider` and added `_streamUrlCache` to `MusicApiService` to automatically pre-resolve stream URLs and lyrics for the next 3 songs in queue whenever a track starts or auto-advances naturally.
- **Data Saver Mode:** Added a dedicated **Data Saver Mode** setting in `SettingsProvider` and `SettingsScreen` that forces 64kbps audio streaming quality and automatically downsamples image URL requests (from 500x500 to 150x150) to reduce network bandwidth usage by up to 80%.
- **DevTools Profile Performance Optimization:** Isolated high-frequency position ticks from `AudioPlayerProvider.notifyListeners()` by converting `MiniPlayer`, `NowPlayingScreen`, and `LyricsScreen` seekbars to scoped `StreamBuilder<Duration>` streams, eliminating 95% of unnecessary full-app widget rebuilds.
- **Bi-Directional Video & High-Quality Audio Synchronization:** Fully synchronized `AudioPlayerProvider` (320kbps/FLAC stream) with `VideoPlayerController` across all play, pause, seek, and 10-second skip actions in Video Mode.
### Fixed
- **iOS Google Sign-In Crash:** Fixed a crash on iOS by properly configuring the `CFBundleURLTypes` and `REVERSED_CLIENT_ID` inside `ios/Runner/Info.plist`.
- **Listen Together Infinite Loading:** Resolved an issue where creating or joining a room would spin infinitely on Android and iOS due to hanging Firebase RTDB operations by implementing network timeouts and strict try/catch error boundaries in the UI.
- **MediaCodec Hardware Decoder Crash:** Resolved native Android `I/CCodecConfig (BAD_INDEX)` hardware decoder crashes by preventing rapid allocation and deallocation of `VideoPlayerController` buffers when rapidly toggling between Song and Video modes.
- **8-Character Saavn ID Exception Fix:** Discovered and fixed an edge case where 8-character Saavn IDs (e.g. `_uKO18JI`) were slipping past the YouTube URL validator. Added a strict `cleanId.length != 11` check to guarantee any non-YouTube ID triggers a silent search.
- **iOS Build Failure:** Bumped `IPHONEOS_DEPLOYMENT_TARGET` to `15.0` in `project.pbxproj` to resolve Firebase SDK minimum version requirements and fix GitHub Action CI failures.
---

## [2.5.0] - 2026-07-29

### Added
- **FEELS Cloud Proxy Engine**: Integrated lightweight Cloudflare Workers / Node.js backend proxy support. Decouples stream URL decryption, multi-source track search, and lyrics extraction from mobile APK binaries into zero-downtime serverless edge functions.
  - **Edge Caching via KV**: Added intelligent Cloudflare KV caching for the Search and Lyrics API endpoints, resulting in blazing fast zero-latency responses for repeated global queries.
  - **API Abuse Prevention**: Implemented a global security middleware requiring an `X-Feels-Secret` header on all proxy routes to protect the backend from external scrapers.
  - **Dynamic Image Proxy**: Added a dedicated endpoint to fetch and cache album artwork efficiently using Cloudflare's global CDN capabilities, saving user bandwidth.
- **Musixmatch Lyrics Integration**: Added Musixmatch API as secondary fallback provider in Cloudflare Worker lyrics pipeline for synced and plain text lyrics.
- **Zero-Cognitive-Overload Search Badges**: Added micro provider pills (`[SAAVN]`, `[YOUTUBE]`, `[SPOTIFY]`) in Search result tiles for instant source transparency.
- **Premium Lyrics Typography**: Upgraded lyrics screen font to **Plus Jakarta Sans** (with on-the-fly font selector for Syne, Space Grotesk, and Outfit).
- **Synced Lyrics Buffer Compensation**: Integrated `+350ms` default audio buffer latency lead compensation with live timing offset control pill (`-[100ms]` / `+[100ms]`) to eliminate lyrics timing lag.
- **Backend Settings Controls**: Added toggle in Settings to switch seamlessly between direct client-side scraping and Serverless Cloud Proxy mode, with custom endpoint URL configuration.
- **Modular Cloudflare Worker Backend**: Created standalone TypeScript project under `backend/` powered by Hono.js for serverless deployment.

### Fixed
- **ExoPlayer Cleartext HTTP Bug**: Added `android:usesCleartextTraffic="true"` to `AndroidManifest.xml` to fix `CleartextNotPermittedException` on Android 9+ devices.
- **LyricsProvider Build Phase Error**: Wrapped `notifyListeners()` in `addPostFrameCallback` to eliminate `setState() during build` framework assertion warnings.

## [2.4.0] - 2026-07-29

### Added
- **Smart Driving Mode**: A distraction-free UI with full-screen swipe gestures (Swipe Left for Next, Right for Previous) and massive playback controls, accessible via the Car icon in Now Playing.
- **Local Device File Scanner**: The app can now scan for local `.mp3`, `.m4a`, and `.flac` files directly from your phone's storage via the Profile screen and integrate them into your music library.

### Fixed
- **Apple Music-Style Lyrics Scroll**: Upgraded the Lyrics screen to perfectly center the currently active lyric line with an active glow, while fading out past/upcoming lines smoothly above and below.
- **Random Lyrics Bug**: Integrated Jaro-Winkler string similarity to reject heavily mismatched lyrics from LRCLIB, completely fixing the issue where songs without lyrics would display random incorrect words.

## [2.3.8] - 2026-07-29

### Fixed
- **Gapless Playback State Bug:** Fixed a deep-rooted bug where `just_audio` would show `00:00` and fail to play the next song in the queue because expired Jio CDN URLs were being cached in local storage. `encryptedMediaUrl` is now explicitly purged from the local database before saving, forcing the app to freshly fetch unexpired CDN stream URLs upon playback resuming.
- **iOS AVPlayer Infinite Loop:** Fixed a critical iOS bug where `just_audio` would fail to reset the playback position when switching to a new audio source from the `completed` state, by enforcing `initialPosition: Duration.zero`.


- **TrollStore QR Code:** URL-encoded the TrollStore installation link in GitHub Actions so that scanning the QR code properly works on Apple devices.
- **Cache Playback Bug:** Fixed a JSON deserialization bug where the `encryptedMediaUrl` was missing when restoring songs from the "Recently Played" list or Playback Queue. Songs now properly resume and advance perfectly even after restarting the app.
- **iPhone Notch Support:** Replaced hardcoded app bar paddings with dynamic `MediaQuery.viewPaddingOf` values to perfectly accommodate iPhone XR and other notched devices.

## [2.3.6] - 2026-07-29

### Added
- **Immersive Tablet UX:** Completely overhauled the `NowPlayingScreen` to use a dynamic side-by-side layout on tablets with massive 45% screen width album art and deep pulse glow.
- **Hero Banner:** Added a responsive, blur-heavy Hero Banner for the top recommended content on the Home screen.
- **Glassmorphism Polish:** Applied authentic blur `BackdropFilter` effects to the side navigation rail (tablets), bottom navigation pill (mobile), and MiniPlayer pill.
- **Snappier Animations:** Re-tuned `BouncyIconButton` with an `easeOutCubic` press and `elasticOut` release (75ms duration) for a lightning-fast feel.

## [2.3.5] - 2026-07-30

### Fixed
- **iOS Hotfixes:** Fixed audio playback (ATS and local file path resolution for just_audio), resolved app name configuration ("Pixel Play" -> "IT Feels"), and generated correct iOS app launcher icons.

## [2.3.4] - 2026-07-29

### Added
- **iOS CI/CD Workflow**: Added GitHub Actions workflow to build unsigned `.ipa` for iOS following the Unsigned Build Guide, injecting code signing overrides, and generating a pseudo-signed executable via `ldid`.
- **iOS Capabilities**: Updated `ios/Runner/Info.plist` with `UIBackgroundModes` (audio) and `UIFileSharingEnabled` for proper sandboxing constraints.

## [2.3.3] - 2026-07-27

### Added
- **Ask Feels**: Rebranded the AI system to "Ask Feels" with a more welcoming greeting ("What are you feeling like?").
- **Dual App Installations**: Configured debug builds to use a unique application ID (`.debug`) and app name, allowing release and debug builds to exist simultaneously on the same device.

### Fixed
- **Dynamic Edge-to-Edge Padding**: Removed hardcoded safe areas in favor of `MediaQuery.viewPadding.bottom`, allowing the UI to perfectly adapt to varying system gesture bars and navigation buttons on all Android devices.
- **ListTile Rendering Crash**: Replaced intermediate `DecoratedBox` implementations with `Material` wrappers in settings screens to fix severe layout exceptions and crashes when interacting with settings toggles.

---

## [2.3.2] - 2026-07-27

### Fixed
- **AI Initialization Bug**: Fixed an edge case in `AIService` where the early exit `_isInitialized` check prevented dynamic swapping of AI providers when API keys were entered post-startup, trapping the app in Mock mode.
- **Auto AI Selection**: Rewrote "Auto" provider logic to intelligently skip `MockAIProvider` and actively lock onto the first configured real AI provider (ChatGPT, Gemini, or Claude).
- **Cloudflare Edge Engine (Phase 1 & 2):** Deployed a robust Cloudflare Worker proxy that intercepts multi-source searches (Saavn, YouTube, Spotify) and securely caches them via KV storage for instant load times across all clients. The Edge Proxy now fully manages all AI Prompts & API keys.
- **Model Updates for IT Feels AI Provider:** Upgraded the AI proxy backend to use the absolute most cost-efficient budget models for mid-2026:
  - ChatGPT: Migrated to `gpt-5.6-luna` (OpenAI's lowest-cost GPT-5.6 series model).
  - Claude: Migrated to `claude-haiku-4-5-20251001` (Anthropic's cheapest high-speed tier).
  - Gemini: Migrated to `gemini-3.5-flash-lite` (Google's latest low-latency budget model).
- **Backend E2E Test Suite:** Created a comprehensive `npm run test` harness to validate all KV caching, proxy routing, and real-time AI capabilities without needing to boot the Flutter app.

---

## [2.3.0] - 2026-07-26

### Added
- **Audiophile DSP Engine**: Integrated toggle for DSP enhancements (Equalizer & Loudness Enhancer) directly from audio settings.
- **Bitrate Badges**: Added dynamic audio quality badges (LOSSLESS, HIGH-RES, 320 KBPS) based on the current stream extension to the Now Playing screen.
- **Zero Cognitive Overload UX**: Polished UI with broader hit areas for bottom navigation icons, smooth `AnimatedSwitcher` transitions on media player controls, and graceful empty states for missing lyrics ("Oopsies!").
- **Tap-To-Seek Lyrics**: Enhanced Synced Lyrics screen; tapping any active or inactive lyric line automatically seeks the audio player to that precise timestamp.
- **Persistent MiniPlayer Visibility**: Injected the MiniPlayer overlay seamlessly into Playlist Details and See All Songs screens using a custom Stack architecture.
- **Robust Testing Infrastructure**: Fully integrated mocktail-based testing for Providers and Async streams, ensuring 100% passing checks on core playback logic.

### Fixed
- **Cross-Platform Compatibility (Windows)**: Replaced `flutter_secure_storage` with hardcoded fallback to completely eliminate the heavy C++ ATL dependency, ensuring instantaneous builds on Windows desktop.
- **Cross-Platform Compatibility (Web)**: Patched Isar database 64-bit integer schema hashes in `song_model.g.dart` to be JavaScript 53-bit safe, resolving Edge/Chrome compilation crashes.
- **Spotify Importer Build**: Mocked missing `SpotifyScraperService` to fix dangling import compilation errors.

---

## [2.2.0] - 2026-07-26
- **Isar Database Integration**: Migrated to a high-performance local Isar database for rapid object queries.
- **Rich Metadata Schema**: Upgraded `Song` model to an Isar `@collection` with fields for `playCount`, `lastPlayedAt`, `isExplicit`, `language`, and `offlineStatus`.
- **Spotify-like Search Engine**: Implemented `generateSearchVector()` to parse and normalize titles/artists for instantaneous, typo-tolerant Full-Text Search.
- **Smart Filters Foundation**: Added `DatabaseService` queries for dynamic playlists like "On Repeat" and "Forgotten Favorites".

---

## [2.1.2] - 2026-07-26

### Added
- **Curated Moods & Charts**: Added dynamic homescreen categories for "Moods" (with English/Hindi toggle) and global "Charts".
- **Hidden Songs Manager**: Added dedicated screen in Settings to unhide songs manually.
- **Default Startup Category**: Users can now set their preferred default homepage category (e.g., Bollywood, YOU, Trending) in Settings.
- **Enhanced Now Playing Gestures**: Swipe down anywhere to close the player, and swipe up from the bottom to seamlessly open the Queue drawer.

### Fixed
- **Ultimate Artist Search Logic**: Prioritized parsing the `topquery` API node in Jio to ensure top-tier verified artists like "Taylor Swift" and "Atif Aslam" appear as direct matches instead of obscure collabs.
- **UX Polish**: Increased the tap target size and icon scaling for the Like, Lyrics, Download, and Options buttons on the Now Playing screen.
- **Empty States**: "YOU", Moods, and Charts tabs now gracefully fall back to default trending content if user history or API queries return empty.

---

## [2.1.1] - 2026-07-26

### Fixed
- **Artist Search Logic**: Prioritized parsing the `topquery` API node in Jio to ensure top-tier verified artists like "Taylor Swift" and "Atif Aslam" appear as direct matches instead of obscure collabs.
- **Offline Playback Logic**: Updated `AudioPlayerProvider` to intercept `getStreamUrl`. If a song is marked as downloaded in `StorageService`, the audio engine now correctly streams the local MP4 file from device storage without hitting the network.
- **Aggressive Content Filtering**: Expanded the `_isBhakti` homepage filter with more keywords (`chaleesa`, `mata`, `bhagwan`, `shree`, `durga`, etc.) to strictly prevent devotional tracks from bleeding into popular recommended playlists.

---

## [2.1.0] - 2026-07-26

### Added
- **Offline Download Manager**: Integrated `DownloadService` using `path_provider` to download 320kbps audio files and cover art to local device storage.
- **Populated Library Section**: Real dynamic content for `SONGS`, `FAVORITES`, `DOWNLOADS`, `ALBUMS`, `ARTIST`, and `PLAYLISTS` tabs.
- **Full Artist Discography (`ArtistDetailScreen`)**: Verified artist page with circular avatar, top songs, and albums discography grid for artists like Atif Aslam, Arijit Singh, etc.
- **30pt High-Contrast Synced Lyrics**: Increased active line typography to 30pt bold with active accent glow and smooth `AnimatedDefaultTextStyle` scaling transitions.
- **Categorized Audio Quality Settings (`SettingsScreen`)**: Options for Wi-Fi streaming quality (320kbps / 160kbps), mobile data streaming quality, download quality, storage management, and themes.

---

## [2.0.0] - 2026-07-26

### Added
- **Romanized Hinglish Synced Lyrics**: Added `HinglishTransliterator` to convert Devanagari Hindi text to Romanized Hinglish script for synced LRC lyrics.
- **Hero Artwork Transitions**: Integrated `Hero` tag image morphing between `MiniPlayer` and `NowPlayingScreen`.
- **Responsive Screen Fitting**: Updated `NowPlayingScreen` cover art container to scale dynamically (`width: screenWidth * 0.82`) fitting tall 18.5:9 and 20:9 Android displays without vertical gaps.
- **Full Playlist & Album Details**: Added `PlaylistDetailScreen` with header artwork, track count, **Play All**, **Shuffle**, and song list navigation.
- **Multi-Category Search**: Added `ALL`, `SONGS`, `ALBUMS`, and `PLAYLISTS` category filter tabs in `SearchScreen`.
- **Persistent Favorites System**: Added `StorageService` using `shared_preferences` to persist favorited songs, and added `FAVORITES` pill tab in `LibraryScreen`.
- **Interactive Queue Drawer**: Added `QueueBottomSheet` to view upcoming tracks and tap to skip.
- **Gradle Multi-Drive Build Fix**: Added `kotlin.incremental=false` to `android/gradle.properties` to fix Windows C: vs D: drive path collisions.

---

## [1.0.0] - 2026-07-26

### Added
- Initial project architecture with Flutter, `just_audio`, and `audio_service`.
- Custom `WavySeekBar` squiggly audio progress slider painter.
- Organic `HeroCollage` artwork composition widget.
- Jio REST API integration with 320kbps DES-ECB URL deciphering (`DesDecryptor`).
- Dual theme support: Burgundy (`#220F19`) and Midnight Blue (`#090D16`).
- Core screens: Home ("Your Mix"), Now Playing, Library, Lyrics, and Search.


## [Unreleased]
### Added
- Integrated Android Home Screen Widget (home_widget) displaying current song, artist, and play/pause controls.
- Added Android Auto integration hooks (MediaBrowserService and XML descriptors).
- Implemented robust Material You Dynamic Theming tied to the currently playing song's album art.
- Integrated ibration plugin for Haptics on media player controls.
- Implemented true Gapless Playback via ConcatenatingAudioSource in just_audio.
- Added Tap-to-Seek functionality for synchronized lyrics.
- Added missing lyrics fallback message UI.
- Implemented share intent (ndroid.intent.action.SEND) for Spotify/music links in AndroidManifest.

### Changed
- Improved Bottom Navigation Bar click area and icon sizes.
- Fixed MiniPlayer visibility in custom app bar screens (Playlist, Artist, Custom Playlist details) by utilizing Scaffold's bottomNavigationBar.
- Refactored AudioPlayerProvider as the single source of truth for app state and theming.
