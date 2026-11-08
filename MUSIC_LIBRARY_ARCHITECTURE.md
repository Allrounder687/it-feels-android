# Music Library Architecture & Local Indexing Specification
**IT Feels Music — Project Obsidian 2026**
*Document Version: 1.0.0 | Status: Production Library Architecture*

---

## 1. Architectural Overview

The Music Library is the personal haven of every music listener. Project Obsidian transforms the library from a static list into a high-speed, indexed, multi-criteria organizing engine (`NewLibraryScreen`).

The architecture leverages a hybrid database model:
1. **Isar NoSQL Engine (`it_feels_db`):** High-performance indexed storage for songs, full-text search vectors, play counts, and completion timestamps.
2. **SharedPreferences Cache:** Rapid synchronous key-value store for user custom playlist structures, offline download registries, and favorite song IDs.

```text
+-----------------------------------------------------------------------------------+
|                         NewLibraryScreen (ConsumerStateful)                       |
|                                                                                   |
|  +---------------------------+       +------------------------------------------+ |
|  | In-Library Search Field   |       | Multi-Select Bulk Action Dock            | |
|  +---------------------------+       +------------------------------------------+ |
|                                                                                   |
|  +---------------------------+       +------------------------------------------+ |
|  | Multi-Criteria Sort Sheet |       | Real-Time Tab Navigator                  | |
|  +---------------------------+       +------------------------------------------+ |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                         Library Collections Coordinator                           |
|                                                                                   |
|  [ Liked Songs ]  [ Downloads ]  [ Playlists ]  [ On Repeat ]  [ Recently Played ]|
+-----------------------------------------------------------------------------------+
                                         |
                    +--------------------+--------------------+
                    |                                         |
                    v                                         v
   +---------------------------------+       +---------------------------------+
   |      Isar Database Engine       |       |     SharedPreferences Registry  |
   |  - Full Text Search Vectors     |       |  - Custom Playlists JSON        |
   |  - Play Count & Time Statistics |       |  - Download File Path Registry  |
   +---------------------------------+       +---------------------------------+
```

---

## 2. Multi-Criteria Sorting Engine

Users can re-sort any active library view instantaneously. Sorting operations execute in memory on pre-indexed collections, delivering sub-15ms re-ordering:

| Sort Option | Key Comparator | Musical Intent |
| :--- | :--- | :--- |
| **`dateAdded`** | `b.addedAt.compareTo(a.addedAt)` | Discover the most recently saved music first (Default). |
| **`titleAsc`** | `a.title.compareTo(b.title)` | Strict alphabetical track order ($A \rightarrow Z$). |
| **`titleDesc`** | `b.title.compareTo(a.title)` | Reverse alphabetical track order ($Z \rightarrow A$). |
| **`artistAsc`** | `a.artist.compareTo(b.artist)` | Group tracks chronologically by artist name. |
| **`durationDesc`**| `b.duration.compareTo(a.duration)` | Surface long recordings, extended mixes, and symphonies. |
| **`playCountDesc`**| `b.playCount.compareTo(a.playCount)` | Reveal personal high-frequency anthems ("On Repeat"). |

---

## 3. Real-Time In-Library Search & Filtering

Unlike global search, in-library search operates strictly on the user's saved and offline collection:
- **Instant Response (< 5ms):** As the user types in `_searchController`, `_applySortingAndFilter()` evaluates queries against normalized track titles, artist names, and album names.
- **Collapsible Design:** Tapping the search icon smoothly expands a glass search container without pushing content off-screen.
- **Cross-Field Coverage:** A query for `"Arijit"` filters all liked songs, downloaded tracks, and custom playlist items featuring the artist.

---

## 4. Multi-Select & Bulk Operations

Managing large collections track-by-track is tedious. Project Obsidian introduces an ergonomic **Multi-Select Mode**:
1. **Activation:** Tap the checklist icon in the library header.
2. **Visual Feedback:** Each `NewMediaTile` displays a cyan check indicator.
3. **Floating Action Dock:** When $\ge 1$ tracks are selected, a floating glass bar ascends from the bottom clearance zone:
   - Displays real-time selection count (`"3 Selected"`).
   - **`Add to...` Action:** Opens a modal sheet allowing one-tap addition of all selected songs to an existing or newly created custom playlist.
   - **`Done` Action:** Commits mutations and dismisses selection mode.

---

## 5. Library Sections & Data Sources

1. **Liked Songs:** Synced reactively with `AudioPlayerState.favoriteSongs` and Isar `isFavorite` flag.
2. **Downloaded Music:** Verified against physical files on disk via `DownloadScannerService` and `StorageService.loadDownloads()`.
3. **Custom Playlists:** Managed via `customPlaylistProvider` with instant creation, track reordering, and cover art resolution from the first song.
4. **On Repeat:** Dynamic query to Isar: tracks with $\text{playCount} \ge 10$ played within the last 14 days, sorted descending by count.
5. **Recently Played:** Sourced from `StorageService.loadPlaybackState()['recentlyPlayed']` containing the last 50 played tracks with timestamps.
