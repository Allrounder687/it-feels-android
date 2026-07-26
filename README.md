# PixelPlayer Saavn 🎵

A premium, modern Flutter Android music application built with the design aesthetics of **PixelPlayer** and powered by the **JioSaavn API**.

![PixelPlayer Saavn Banner](https://img.shields.io/badge/PixelPlayer-Saavn%20Edition-FF4081?style=for-the-badge&logo=flutter)
![Flutter Version](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

---

## ✨ Highlights & Key Features

- **PixelPlayer UI Aesthetics**: High-contrast dark themes (Burgundy `#220F19` & Midnight Blue `#090D16`), organic artwork bubble collages (`HeroCollage`), display typography (`Outfit` & `Inter`), and custom squiggly progress bars (`WavySeekBar`).
- **JioSaavn 320kbps High Quality Audio**: Real-time DES-ECB link decryption and 320kbps AAC/MP4 stream URL resolution (`DesDecryptor`).
- **Romanized / Hinglish Synced Lyrics**: Automatic Devanagari-to-Romanized transliteration (`HinglishTransliterator`) and LRCLIB script filtering so Hindi synced lyrics are presented in Roman English text.
- **Hero Artwork Transitions**: Seamless morphing of album cover art between `MiniPlayer` and `NowPlayingScreen`.
- **Full Playlist & Album Support**: Dedicated `PlaylistDetailScreen` with cover image, track count, **Play All**, **Shuffle**, and song list navigation.
- **Multi-Category Search**: Search across `SONGS`, `ALBUMS`, and `PLAYLISTS` with category filter tabs.
- **Persistent Favorites System**: Persistent local storage using `shared_preferences` (`StorageService`) and a dedicated `FAVORITES` pill tab in Library.
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
- **Local Storage**: `shared_preferences`
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
   git clone https://github.com/PixelPlayerHQ/PixelPlayer.git
   cd PixelPlayer
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
