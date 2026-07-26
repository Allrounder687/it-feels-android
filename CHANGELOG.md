# Changelog

All notable changes to **PixelPlayer Saavn Edition** will be documented in this file.

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
- JioSaavn REST API integration with 320kbps DES-ECB URL deciphering (`DesDecryptor`).
- Dual theme support: Burgundy (`#220F19`) and Midnight Blue (`#090D16`).
- Core screens: Home ("Your Mix"), Now Playing, Library, Lyrics, and Search.
