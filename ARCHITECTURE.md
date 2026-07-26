# System Architecture - PixelPlayer Saavn

This document details the architectural layout, state flow, encryption pipeline, and directory structure of the PixelPlayer Saavn Flutter Android application.

---

## 🏗️ High-Level System Architecture

```
                               ┌─────────────────────────┐
                               │   Flutter Presentation   │
                               │ (Views, Widgets, Hero)  │
                               └────────────┬────────────┘
                                            │
                               ┌────────────▼────────────┐
                               │  Provider State Layer   │
                               │ (Audio, Search, Home)   │
                               └──────┬────────────┬─────┘
                                      │            │
             ┌────────────────────────┘            └────────────────────────┐
             ▼                                                              ▼
┌─────────────────────────┐                                    ┌─────────────────────────┐
│     Services Layer      │                                    │  Background Audio Handler│
│ (JioSaavn API, Lyrics,  │                                    │ (just_audio / AudioSvc) │
│   Storage, Encryption)  │                                    └─────────────────────────┘
└────────────┬────────────┘
             │
 ┌───────────┴───────────┐
 ▼                       ▼
[JioSaavn REST]     [LRCLIB Synced]
```

---

## 📂 Project Structure

```
lib/
├── core/
│   ├── theme/
│   │   └── app_colors.dart         # Burgundy & Midnight Blue design system tokens
│   └── utils/
│       ├── des_decryptor.dart      # JioSaavn DES-ECB link decipher & 320kbps upgrade
│       ├── hinglish_transliterator.dart # Devanagari to Romanized Hinglish transliterator
│       └── lrc_parser.dart          # Synced LRC timestamp parser
├── data/
│   ├── models/
│   │   └── song_model.dart         # Song, Playlist, and LyricLine data models
│   └── services/
│       ├── audio_player_handler.dart# AudioService background playback handler
│       ├── jiosaavn_api_service.dart# JioSaavn API client (search, playlists, albums)
│       └── lyrics_service.dart     # Static JioSaavn & LRCLIB synced lyrics loader
├── providers/
│   ├── audio_player_provider.dart  # Playback state, queue, favorite persistence & palette
│   ├── home_provider.dart          # Homepage trending content state
│   ├── lyrics_provider.dart        # Lyrics mode & autoscroll index
│   └── search_provider.dart        # Multi-category search state
├── services/
│   └── storage_service.dart        # SharedPreferences local storage persistence
└── views/
    ├── details/
    │   └── playlist_detail_screen.dart # Playlist & Album full detail view
    ├── home/
    │   └── home_screen.dart        # Screen 1: "Your Mix" & HeroCollage
    ├── library/
    │   └── library_screen.dart     # Screen 3: Track list & FAVORITES tab
    ├── lyrics/
    │   └── lyrics_screen.dart      # Screen 4: Live synced LRC lyrics view
    ├── player/
    │   ├── now_playing_screen.dart # Screen 2: Responsive player & WavySeekBar
    │   └── queue_bottom_sheet.dart # Active playback queue drawer
    ├── search/
    │   └── search_screen.dart      # Categorized search (Songs, Albums, Playlists)
    └── widgets/
        ├── hero_collage.dart       # Organic bubble artwork widget
        ├── mini_player.dart        # Floating mini player pill
        └── wavy_seek_bar.dart      # Custom animated squiggly progress bar
```

---

## 🔐 Audio Decryption Pipeline

1. JioSaavn returns an encrypted base64 payload in `encrypted_media_url`.
2. `DesDecryptor.decrypt` uses PointyCastle 3DES (`DESedeEngine`) with key `38346591` (repeated 3x) to decrypt DES-ECB.
3. `DesDecryptor.get320kbpsUrl` upgrades the CDN link from 96/160kbps to 320kbps AAC (`_320.mp4` / `aac.saavncdn.com`).
4. `just_audio` streams the high quality audio directly to native Android `AudioTrack`.
