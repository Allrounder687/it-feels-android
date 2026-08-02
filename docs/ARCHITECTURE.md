# System Architecture - IT Feels Music

This document details the architectural layout, state flow, encryption pipeline, and directory structure of the IT Feels Music Flutter Android application. It also serves as a foundational resource for AI agents contributing to the project, as outlined in [STEERING_PATH.md](STEERING_PATH.md).

---

## 🏗️ High-Level System Architecture

```
                               ┌─────────────────────────┐
                               │   Flutter Presentation   │
                               │ (Views, Widgets, Hero)  │
                               └────────────┬────────────┘
                                            │
                               ┌────────────▼────────────┐
                               │  Riverpod State Layer   │
                               │(Audio, Search, Settings)│
                               └──────┬────────────┬─────┘
                                      │            │
             ┌────────────────────────┘            └────────────────────────┐
             ▼                                                              ▼
┌─────────────────────────┐                                    ┌─────────────────────────┐
│     Services Layer      │                                    │  Background Audio Handler│
│ (JioSaavn API, Lyrics,  │                                    │ (just_audio / AudioSvc) │
│ Download, Encryption)   │                                    └─────────────────────────┘
└────────────┬────────────┘
             │
 ┌───────────┴───────────┐
 ▼                       ▼
[JioSaavn REST]     [Local Storage / path_provider]
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
│       ├── jiosaavn_api_service.dart# JioSaavn API client (search, playlists, albums, artists)
│       └── lyrics_service.dart     # Static JioSaavn & LRCLIB synced lyrics loader
├── providers/
│   ├── audio_player_provider.dart  # Playback state, queue, favorite persistence & palette
│   ├── home_provider.dart          # Homepage trending content state
│   ├── lyrics_provider.dart        # Lyrics mode & autoscroll index
│   ├── search_provider.dart        # Multi-category search state
│   └── settings_provider.dart      # Audio quality, streaming & theme preferences
├── services/
│   ├── download_service.dart       # Local audio file & cover downloader engine
│   └── storage_service.dart        # SharedPreferences local storage persistence
└── views/
    ├── details/
    │   ├── artist_detail_screen.dart # Full artist discography view
    │   └── playlist_detail_screen.dart # Playlist & Album full detail view
    ├── home/
    │   └── home_screen.dart        # Screen 1: "Your Mix" & HeroCollage
    ├── library/
    │   └── library_screen.dart     # Screen 3: Populated tabs (Songs, Favorites, Downloads, Albums, Artists, Playlists)
    ├── lyrics/
    │   └── lyrics_screen.dart      # Screen 4: 30pt high-contrast synced lyrics view
    ├── player/
    │   ├── now_playing_screen.dart # Screen 2: Responsive player & WavySeekBar
    │   └── queue_bottom_sheet.dart # Active playback queue drawer
    ├── search/
    │   └── search_screen.dart      # Categorized search (Songs, Artists, Albums, Playlists)
    ├── settings/
    │   └── settings_screen.dart    # Audio quality & storage settings screen
    └── widgets/
        ├── hero_collage.dart       # Organic bubble artwork widget
        ├── mini_player.dart        # Floating mini player pill
        └── wavy_seek_bar.dart      # Custom animated squiggly progress bar
```
