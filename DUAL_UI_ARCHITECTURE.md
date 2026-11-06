# DUAL UI ARCHITECTURE: IT FEELS MUSIC

## 1. Architectural Philosophy

The Dual UI Architecture establishes a strict boundary between the **Core Business / Domain Layer** and two independent **Presentation Layers**:

1. **Classic UI Layer** (`lib/features/...` - original screens and widgets)
2. **New Experience Layer** (`lib/features/new_experience/...`)

```
+-----------------------------------------------------------------------------------+
|                              FLUTTER APPLICATION ROOT                            |
|                               (MaterialApp.router)                                |
+-----------------------------------------+-----------------------------------------+
                                          |
                        [AppExperience Selector / Router]
                                          |
                 +------------------------+------------------------+
                 |                                                 |
                 v                                                 v
   +---------------------------+                     +---------------------------+
   |   CLASSIC UI PRESENTATION |                     | NEW EXPERIENCE (2026 UI)  |
   |   (MainNavigationWrapper) |                     |  (NewExperienceShell)     |
   | - HomeScreen              |                     | - NewHomeScreen           |
   | - SearchScreen            |                     | - NewSearchScreen         |
   | - LibraryScreen           |                     | - NewLibraryScreen        |
   | - NowPlayingScreen        |                     | - NewNowPlayingScreen     |
   | - PlaylistDetailScreen    |                     | - NewPlaylistDetailScreen |
   | - SettingsScreen          |                     | - NewArtistDetailScreen   |
   +-------------+-------------+                     +-------------+-------------+
                 |                                                 |
                 +------------------------+------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                           SHARED CORE APPLICATION STATE                           |
|                      (Riverpod Providers & Singletons)                            |
|                                                                                   |
|  - audioPlayerProvider (Playback engine, queue, shuffle, repeat, stream URL cache)|
|  - musicRepositoryProvider / IMusicRepository (JioSaavn catalogue, AddonManager)  |
|  - downloadProvider / DownloadService (File storage, Isar sync, background jobs)  |
|  - authProvider / AuthService (Firebase Anonymous, Guest Mode, Cloud auth)        |
|  - settingsProvider / StorageService (Preferences, quality, cache settings)       |
|  - listeningHistoryProvider / DatabaseService (Recently played, Isar DB)          |
|  - customPlaylistProvider (User created playlists, JSON/Isar storage)            |
|  - TrackValidationEngine (Studio deduplication, acoustic heuristic ranking)       |
+-----------------------------------------------------------------------------------+
```

---

## 2. Key Architecture Guarantees

1. **No Duplicate State**: A single instance of `AudioPlayerNotifier` exists in memory. Switching UI experiences does not restart audio, does not re-fetch current stream URLs, and does not alter the playback position.
2. **Reversible Live Switching**: The user can switch between Classic and New Experience at any time directly in `Settings -> Appearance -> App Experience`. The change takes effect instantaneously without requiring an application restart.
3. **Classic UI Preservation**: Zero lines of existing UI code are deleted. Classic UI remains completely functional and is the default for existing installations.
4. **Independent Styling & Tokens**: The New Experience utilizes its own dedicated tokens (`NewExperienceTokens`, `NewAmbientCanvas`), ensuring zero visual leakage or style collisions with Classic UI.
5. **Cross-Platform Responsive Adaptivity**: The New Experience shell actively monitors viewport width constraints (`constraints.maxWidth`), dynamically selecting between:
   - Desktop 3-pane layout ($\ge 1024\text{dp}$)
   - Tablet / Mobile Landscape multi-column layout ($600\text{dp} - 1024\text{dp}$)
   - Mobile Portrait bottom island dock ($< 600\text{dp}$)

---

## 3. Shared Functionality Verification Matrix

| Functionality | Classic UI Source | New Experience Consumer | Parity / Sharing Status |
|---|---|---|---|
| **Audio Playback** | `audioPlayerProvider` | `ref.watch(audioPlayerProvider)` | 100% Identical Singleton Player |
| **Track Queue** | `AudioPlayerState.queue` | `AudioPlayerState.queue` | 100% Shared Queue & Reorder |
| **Catalogue & Search** | `MusicRepository` / `AddonManager` | `MusicRepository` / `AddonManager` | 100% Shared JioSaavn API |
| **Track Deduplication** | `TrackValidationEngine` | `TrackValidationEngine` | 100% Shared Acoustic Heuristic |
| **Download Management** | `downloadProvider` / `DownloadService` | `ref.watch(downloadProvider)` | 100% Shared Isar Offline Database |
| **Custom Playlists** | `customPlaylistProvider` | `ref.watch(customPlaylistProvider)` | 100% Shared Storage |
| **Listening History** | `listeningHistoryProvider` | `ref.watch(listeningHistoryProvider)` | 100% Shared History Log |
| **Authentication** | `authProvider` / `AuthService` | `ref.watch(authProvider)` | 100% Shared Session |
| **Synced Lyrics** | `LyricsService` / `lyricsProvider` | `LyricsService` / `lyricsProvider` | 100% Shared LRCLIB & Saavn Engine |
| **Settings & Audio FX** | `settingsProvider` / `StorageService` | `settingsProvider` / `StorageService` | 100% Shared Preferences |
