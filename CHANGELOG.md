# Changelog

All notable changes to **IT Feels Music** will be documented in this file.

## [2.5.0] - 2026-07-29

### Added
- **FEELS Cloud Proxy Engine**: Integrated lightweight Cloudflare Workers / Node.js backend proxy support. Decouples stream URL decryption, multi-source track search, and lyrics extraction from mobile APK binaries into zero-downtime serverless edge functions.
- **Musixmatch Lyrics Integration**: Added Musixmatch API as secondary fallback provider in Cloudflare Worker lyrics pipeline for synced and plain text lyrics.
- **Zero-Cognitive-Overload Search Badges**: Added micro provider pills (`[SAAVN]`, `[YOUTUBE]`, `[SPOTIFY]`) in Search result tiles for instant source transparency.
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
- **Edge-to-Edge System Navigation**: Wrapped the floating Bottom Navigation Bar overlay in a `SafeArea` to prevent the Android OS navigation gesture pill / 3-button layout from clipping and hiding the custom UI.

---

## [2.3.1] - 2026-07-27

### Added
|- **AI Model Upgrades:** ChatGPT upgraded to `gpt-5-mini-2025-08-07`, Claude Haiku to `claude-haiku-4-5-20251001`, and Gemini to `gemini-2.5-flash` for lower-cost, higher-performance playlist generation (see `lib/core/ai/providers/`).

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
