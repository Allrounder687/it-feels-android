# IT Feels Music v3.7.1 — Sleek UX Overhaul, Playback Resilience & Clean UI Release

A comprehensive UI/UX overhaul and core playback stabilization release addressing truncated song titles, removing oversized clunky text boxes, deploying Spotify-grade minimalist action controls across all screen sizes, and completely resolving random playback stalls and audio focus drops.

---

### 🌟 Key Highlights

#### 1. 🎵 Core Playback Resilience & Zero-Stall Audio Pipeline
- **AudioSession & Focus Management**: Properly configured `AudioSession` with `AudioSessionConfiguration.music()`, explicit `session.setActive(true)`, and interruption recovery handling so background playback and external audio focus interruptions do not silently freeze the audio track.
- **CDN Stream Cache Eviction & 2-Hour TTL**: Replaced unbounded stream caching in `MusicRepository` with a 2-hour TTL cache (`_StreamCacheEntry`) and proactive eviction (`evictStreamCache`) on network errors and playback skips, eliminating 403 Forbidden dead-URL loops that previously forced app restarts.
- **12-Second Network Watchdog**: Added a timeout watchdog to `_player.open()` preventing background media reader loops from hanging indefinitely on stalled CDN connections.

#### 2. ✨ Complete UI/UX Modernization & Anti-Bloat
- **Eliminated Ugly Text Boxes**: Removed the permanent, oversized "Filter tracks in playlist..." input box. Replaced it with an on-demand, sleek collapsible search toggle that opens only when the user requests it.
- **Sleek Spotify-Grade Action Bar**: Replaced the 4 bulky text pills (`Play`, `Shuffle`, `Play Next`, `Add to Queue`) in playlist details with a unified, high-contrast action bar: minimalist circular glass buttons for Shuffle, Play Next, Add to Queue, and Search, paired with a prominent glowing circular Play FAB.
- **Zero Truncated Song Titles Across All Formats**: Enhanced `NewMediaTile` with 2-line dynamic title wrapping, adaptive font sizing, constrained 32px trailing button hit targets, and streamlined horizontal padding (14px) so song titles and artist names are fully visible on compact phones, standard devices, tablets, and desktops.
- **Streamlined Library Screen**: Reduced filter chip height to a crisp 36px, compacted the quick actions bar to 32px, and replaced the bulky 104px Liked Songs card with a sleek 56px pinned obsidian card (rendered only on the 'All' tab).

#### 3. 📥 Download Management & Storage Safeguards
- **Direct Deletion & Swipe-to-Delete**: Added dedicated one-tap delete button with obsidian confirmation modal and swipe-to-delete gesture across downloaded tracks.
- **Anti-AutoScan Protection**: Prevented startup disk scanning from ingesting uncurated, coverless local audio files into the library database.
- **Clear All Downloads Hero Action**: Added quick batch cleanup with instant Riverpod disk storage calculation.

---

### 📦 Artifacts in this Release

| Platform | Format | File Name | Size |
| :--- | :--- | :--- | :--- |
| **Windows** | Inno Setup Installer | `IT_Feels_Music_v3.7.1_Setup.exe` | ~40 MB |
| **Android** | Signed Release APK | `IT_Feels_v3.7.1.apk` | ~155 MB |
