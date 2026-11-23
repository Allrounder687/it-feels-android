# IT Feels Music v3.7.6 — Complete Cross-Platform Production Release

Full production release delivering the complete suite of connected music performance optimizations, session audio negotiation, background playback lifecycle resilience, and atomic playlist caching across Android and Windows.

---

### 🌟 Key Highlights

#### 1. 🎵 Connected Music Performance & Real Audio Recovery
- **Lightweight Same-Origin Reader**: Replaced full background SPA loads with lightweight readers, reducing memory footprint and startup latency.
- **Serialized Concurrent Readers**: Staggered cached startup refreshes to prevent socket contention on initial app launch.
- **Session-Granted Audio Negotiation**: Implemented dynamic session-negotiated audio resolution inside the YouTube addon, with robust result fallbacks and signed CDN URL cache eviction.
- **Muxed Audio Resolution**: Accepts playable muxed streams with explicit dynamic `Referer` injection (`youtube.com` vs `jiosaavn.com`), permanently resolving HTTP 403 Forbidden errors.

#### 2. 📱 Android Background Playback & Lifecycle Resilience
- **Mobile Lifecycle Protection**: Gated UI activity detachment to Desktop platforms. Background audio service continues playback uninterrupted when minimizing to the home screen.
- **Self-Healing Audio Player**: Added automatic recovery (`_ensurePlayerAlive`) across all player controls so playback resurrects without ever requiring an app force-stop.
- **Standard Task Affinity & Notifications**: Restored default Android OS task stack affinity and declared `POST_NOTIFICATIONS` permission for foreground media playback on Android 13/14+.
- **Cleaned Device Route Listeners**: Made `devicesChangedEventStream` informational on mobile to eliminate spurious pauses when virtual recording endpoints change.

#### 3. ⚡ Instant Playlist Loading & Atomic Snapshot Storage
- **Atomic Disk Cache**: Implemented bounded 32-entry / 32 MB atomic playlist snapshot cache with per-service cleanup.
- **Instant Cold Loading**: Restores cached playlist tracks immediately upon app open with zero waiting time, while performing quiet background refreshes.

#### 4. 🖼️ Visual Polish & Crash Elimination
- **Album Cover Stem Deduplication**: Prevents duplicate artwork and repeated posters across trending album shelves.
- **Hits Screen Flex Stability**: Replaced invalid `Wrap`/`Spacer` widget hierarchy in `NewHitsScreen` with flex-safe `Row` layout, permanently resolving grey screen render exceptions.

---

### 📦 Artifacts in this Release

| Platform | Format | File Name | Size |
| :--- | :--- | :--- | :--- |
| **Windows** | Inno Setup Installer | `IT_Feels_Music_v3.7.6_Setup.exe` | ~40 MB |
| **Android** | Signed Release APK | `IT_Feels_v3.7.6.apk` | ~156 MB |
