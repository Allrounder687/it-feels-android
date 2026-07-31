
# IT Feels Music  🎵

A premium, modern Flutter Android music application built with the design aesthetics of **IT Feels Music** and powered by the **FEELS Cloud Proxy Engine**.

![IT Feels Music Banner](https://img.shields.io/badge/IT%20Feels%20Music-Edition-FF4081?style=for-the-badge&logo=flutter)
![Version](https://img.shields.io/badge/Version-3.2.0-blue?style=for-the-badge)
![Flutter Version](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

---

## ✨ Highlights & Key Features

- **IT Feels Music UI Aesthetics**: High-contrast dark themes (Burgundy `#220F19` & Midnight Blue `#090D16`), organic artwork bubble collages (`HeroCollage`), display typography (`Outfit` & `Inter`), and custom squiggly progress bars (`WavySeekBar`).
- **Zero Cognitive Overload UX**: Graceful empty states, smooth animated transitions on all player controls, and zero-wait background video loading that falls back to 60fps album art while resolving streams.
- **Unified Multi-Backend Search Engine**: Concurrently queries both the Saavn API and the IT-Feels Native Catalog, automatically merging, deduplicating, and relevance-sorting results with distinct UI badging.
- **Instant Native Video Extraction**: Bypasses external proxies with a highly optimized local `youtube_explode_dart` engine that strictly fetches pre-muxed 720p streams to guarantee zero-latency audio/video synchronization.
- **Multi-Provider Smart Playlist Engine:** Leverages three highly cost-efficient 2026 LLM backend proxies (ChatGPT `gpt-5.6-luna`, Claude `haiku-4-5-20251001`, Gemini `3.5-flash-lite`) for playlist generation, fully protected and routed via the Cloudflare Edge.
- **Backend E2E Validation:** Ships with a standalone native Node.js testing harness (`npm run test`) for the Cloudflare Worker to rapidly iterate on AI prompts and KV caching without needing the mobile client.
- **Curated Moods & Charts**: Dedicated dynamic tabs for curated mood playlists (with English/Hindi toggle) and top global streaming charts.
- **Hidden Songs Manager**: Full control over your feed with the ability to hide unwanted songs and manage them via a dedicated privacy setting.
- **Fully Populated Library Tabs**: Real dynamic data for `SONGS`, `FAVORITES`, `DOWNLOADS`, `ALBUMS`, `ARTIST`, and `PLAYLISTS`.
- **Offline Download Manager**: Full `DownloadService` allowing users to download 320kbps audio streams (`.mp3`/`.mp4`) and cover art to local device storage (`path_provider`) for offline playback.
- **Full Artist Discography (`ArtistDetailScreen`)**: Artist search (e.g., "Atif Aslam", "Arijit Singh") displays verified artist cards with avatar image, top songs, and discography albums & singles grid.
- **Cloud-Powered High Quality Audio**: Real-time DES-ECB link decryption and 320kbps AAC/MP4 stream URL resolution (`DesDecryptor`).
- **30pt High-Contrast Synced Lyrics**: Devanagari-to-Romanized transliteration (`HinglishTransliterator`) with enlarged 30pt bold active line autoscroll, interactive tap-to-seek playback, and smooth scale transitions.
- **Categorized Audio Quality & Settings**: Dedicated `SettingsScreen` for Wi-Fi streaming quality (`320 kbps` / `160 kbps`), mobile data quality, download quality, storage management, and theme selection.
- **Hero Artwork Transitions & Persistent MiniPlayer**: Seamless morphing of album cover art and persistent MiniPlayer visibility across all internal app routes.
- **Interactive Queue Drawer**: Bottom sheet (`QueueBottomSheet`) displaying upcoming tracks with tap-to-skip functionality.
- **Background Playback & Lockscreen Controls**: Full Android `AudioService` integration with system notification media controls.

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: Flutter (Dart)
- **Audio Playback Engine**: `just_audio` & `audio_service`
- **Networking**: `http`
- **Crypto & Decryption**: `encrypt` & `pointycastle` (DES-ECB deciphering)
- **State Management**: `provider`
- **Image Caching & Palette**: `cached_network_image` & `palette_generator`
- **Local Storage & Database**: `isar`, `shared_preferences` & `path_provider`
- **UI & Fonts**: `google_fonts` (Outfit & Inter)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.x+)
- Android SDK (API Level 21+)
- Connected Android Device or Emulator

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/IT Feels MusicHQ/IT Feels Music.git
   cd IT Feels Music
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run on your connected Android device:
   ```bash
   flutter run -d <device-id>
   ```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## Recent Updates
- **World-Class Architecture Upgrade (3.1.0):** Deployed a Zero-Buffering local caching audio engine, Concurrent Network Racing for instant streaming, True Native OS Background Downloading, Live Karaoke Auto-Scroll, and Advanced Cloud Telemetry.
- **Phase 3 Authentication (Listen Together):** Implemented Firebase Core and a highly secure, Zero Cognitive Overload Magic Auth bottom sheet for seamless cloud syncing.
- **Ask Feels AI Engine:** Branded and updated smart playlist capabilities featuring "What are you feeling like?" UX.
- **Dynamic UI Padding:** Fluid edge-to-edge screens that adapt flawlessly to native Android gesture bars and system insets.
- **Audiophile DSP Engine:** Built-in Equalizer and Loudness Enhancer with zero-config smart toggles.
- **Bitrate Badges:** Visually distinguish between LOSSLESS, HIGH-RES, and 320 KBPS audio streams dynamically on the player screen.
- **Cross-Platform Refinements:** Eliminated heavy C++ ATL dependencies for fast Windows compilation and patched Isar for Web compatibility.
- **Gapless Playback:** Seamless transitions between tracks using ConcatenatingAudioSource.
- **Android Home Widget:** Control your music right from the home screen.
- **Dynamic Theming (Material You):** The app adapts perfectly to the album art of the currently playing track.
- **Haptic Feedback:** Subtle, premium haptic responses on player controls.
- **Android Auto Support:** Preparation for automotive integration.
- **TrollStore iPad Support:** Correctly formatted QR codes for 1-tap installation via iOS/iPadOS camera.
- **Flawless Playback Cache:** Robust JSON fallback mechanisms that guarantee Recently Played and Queue states resume flawlessly even after hard restarts.
- **Tablet & Large Screen UI:** Added dynamic side-by-side player layouts, Hero Banners, and authentic glassmorphism for a stunning tablet experience.
- **Cloudflare Edge Acceleration:** Deployed Phase 1 Cloudflare Worker enhancements including KV caching for zero-latency searches/lyrics, a dynamic Image Proxy cache for CDN acceleration, and robust API Abuse Prevention via the `X-Feels-Secret` HTTP header.
