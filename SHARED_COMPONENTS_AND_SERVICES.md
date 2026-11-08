# IT Feels Music — Shared Components & Services Reference
**Project Obsidian — Phase 4: Application-Wide Feature Completeness & Standardization**  
*Document Version: 3.9.3 | Target: Clean/Addon Upstream (IT_Feels_Alternate)*

---

## 1. Shared UI Components

### 1. `NewMediaTile` (`lib/features/new_experience/widgets/new_media_tile.dart`)
- **Purpose:** Universal media list row used across Library, Album, Artist, Playlist, Hits, and Search.
- **Key Optimizations:**
  - Granular Riverpod boolean selector (`s.currentSong?.id == widget.song.id`) eliminating full-list rebuilds on track changes.
  - Animated frequency equalizer bars wrapped in `RepaintBoundary`.
  - Right-click secondary tap (desktop) and long-press (mobile) opening `SongOptionsSheet`.
  - Dynamic index ranking badge or artwork thumbnail based on context.

### 2. `NewArtworkImage` (`lib/features/new_experience/widgets/new_artwork_image.dart`)
- **Purpose:** High-performance, memory-bounded cover art rendering widget.
- **Key Optimizations:**
  - Bounded memory decode (`memCacheWidth` / `memCacheHeight` clamped between $64\text{px}$ and $800\text{px}$).
  - Multi-source resolution: local files (`C:\...`), `file://` schemes, and remote HTTPS URLs with cached network fallback.
  - In-memory existence caching (`_localFileCache`) eliminating UI isolate synchronous disk I/O stalls during flings.

### 3. `SongOptionsSheet` (`lib/core/widgets/song_options_sheet.dart`)
- **Purpose:** Context menu modal exposing track actions.
- **Key Features:**
  - Experience-aware routing: routes to `NewArtistDetailScreen`, `NewAlbumDetailScreen`, and `NewTrackDetailScreen`.
  - Reactive favorite and download toggles reflecting live provider state.

### 4. `NewGlassContainer` (`lib/features/new_experience/widgets/new_glass_container.dart`)
- **Purpose:** Obsidian glassmorphic card container with specular border and adaptive backdrop blur.
- **Key Features:**
  - Dynamically throttles blur radius based on `GraphicsQuality` settings to preserve 60/120 FPS on lower-tier hardware.

### 5. `NewAudioScrubber` (`lib/features/new_experience/widgets/new_audio_scrubber.dart`)
- **Purpose:** High-precision audio progress bar.
- **Key Features:**
  - Local drag-buffering: position updates are isolated from the parent widget tree during dragging.
  - Bounded seeking: dispatches seeks strictly on touch/pointer release (`onChangeEnd`).
  - Haptic notch feedback on whole-minute marks.

---

## 2. Shared Core Services

### 1. `AudioPlayerHandler` & `AudioPlayerNotifier`
- **Location:** `lib/services/audio_player_handler.dart`, `lib/features/player/audio_player_provider.dart`
- **Core State:** `isPlaying`, `currentSong`, `queue`, `currentIndex`, `isShuffle`, `isRepeat`, `isSleepTimerActive`.
- **Key Capabilities:**
  - `shufflePlayContext(List<Song> songs, {int? initialIndex})`: Atomic Fisher-Yates shuffle engine initialization and playback start.
  - `playNextBatch(List<Song> songs)`: Immediate batch queue insertion after active track.
  - Consecutive playback failure circuit breaker (trips on 3 consecutive track failures).
  - Bounded seek clamping preventing decoder deadlocks.

### 2. `EqualizerService`
- **Location:** `lib/data/services/equalizer_service.dart`
- **Capabilities:**
  - Studio-grade 10-Band Graphic Equalizer ($31\text{Hz}$ to $16\text{kHz}$) utilizing libmpv biquad filters.
  - Bass Boost ($0-10\text{dB}$), Treble Boost ($0-10\text{dB}$), Preamp Gain ($-12\text{dB}$ to $+12\text{dB}$), and EBU R128 Loudness Normalization.
  - 10 curated acoustic presets.

### 3. `CustomPlaylistNotifier`
- **Location:** `lib/features/library/custom_playlist_provider.dart`
- **Capabilities:**
  - Reactive playlist state (`playlists`).
  - `reorderSongs(String playlistId, int oldIndex, int newIndex)`.
  - `removeSongsBatch(String playlistId, List<String> songIds)`.
  - `duplicatePlaylist(String playlistId)`.
  - Safe persistence via `DataIntegrityService`.

### 4. `DownloadNotifier` & `DownloadScannerService`
- **Location:** `lib/features/library/download_provider.dart`, `lib/services/download_scanner_service.dart`
- **Capabilities:**
  - Scoped directory discovery restricting desktop scans to dedicated music folders.
  - `computeTotalStorageBytes()` calculating physical disk footprint.
  - `removeDownloadsBatch(List<Song> songs)` deleting audio files, companion JSONs, and companion artwork.
  - Automatic metadata healing via `MetadataRestorationService`.

### 5. `DataIntegrityService`
- **Location:** `lib/services/data_integrity_service.dart`
- **Capabilities:**
  - Two-phase safe writes with JSON validation.
  - Rolling backup snapshots (`${key}_backup_snapshot`).
  - Automated self-healing rollback (`safeReadString`).

### 6. `CrashDiagnosticsService`
- **Location:** `lib/services/crash_diagnostics_service.dart`
- **Capabilities:**
  - Structured reproduction identifiers (`ERR-PLBK-XXXXX`, `ERR-NET-XXXXX`, etc.).
  - Automated multi-pattern privacy scrubbing (Bearer tokens, emails, passwords, API keys, personal directory paths).
  - In-memory circular buffer (150 items) and cross-crash persistent snapshot in SharedPreferences.
