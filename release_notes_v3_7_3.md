# IT Feels Music v3.7.3 — Connected Accounts, YouTube Streams & Playback Reliability Release

High-impact release delivering major reliability fixes for Connected Accounts (YouTube Music & Spotify), seamless playback and download resolution for YouTube streams, permanent playlist persistence, and UI layout fixes.

---

### 🌟 Key Highlights

#### 1. 🎵 Connected YouTube Playback & Download Resolution
- **Muxed Stream Resolution**: Updated `AudioSourcePolicy` to accept muxed streams (`videoOnly: false`) when dedicated audio-only streams are not provided by resolvers.
- **Dynamic Referer Injection**: `AudioPlayerHandler` and `DownloadService` dynamically inject correct HTTP `Referer` headers (`https://www.youtube.com/` for YouTube/googlevideo CDNs vs Saavn CDN), eliminating HTTP 403 Forbidden errors and enabling smooth playback and offline downloads.

#### 2. ⚡ Instant Playlist Loading & Permanent Persistence
- **Two-Tier Playlist Cache**: Implemented in-memory caching and persistent encrypted disk storage (`store.write` / `store.read`) for connected account playlists.
- **Instant Cold Loading**: Playlists load immediately from local snapshot storage on startup with zero wait time, while refreshing in the background.
- **Generated Mix Persistence**: Daily and dynamic mix tracks are automatically persisted via `DynamicPlaylistService`.

#### 3. 🔐 Single-Step Connected Account Login & Modern Spotify Auth
- **Eliminated Double Login**: Added 600ms settling delay to allow WebView cookies to flush to disk before popping the login view; added `google.com` and `google.co.in` cookie capture domains.
- **Premature Login Exception Guard**: Prevented `AccountBrowserGateway` from misinterpreting transitional redirects as authentication failures.
- **Modern Spotify Token Intercept**: Updated `spotify.js` to intercept `/get_access_token?reason=transport&productType=web_player` and added automatic active fallback token retrieval.

#### 4. 🎨 Album Artwork Variety & UI Fixes
- **Album Poster Deduplication**: Upgraded `CatalogueDeduplicationEngine` with cover art stem deduplication to prevent duplicate album posters across trending feeds.
- **Hits Screen Gray Screen Fix**: Replaced improper `Spacer` inside `Wrap` with flex-safe `Row` layout in `NewHitsScreen`, permanently resolving unhandled layout exceptions.

---

### 📦 Artifacts in this Release

| Platform | Format | File Name | Size |
| :--- | :--- | :--- | :--- |
| **Windows** | Inno Setup Installer | `IT_Feels_Music_v3.7.3_Setup.exe` | ~40 MB |
| **Android** | Signed Release APK | `IT_Feels_v3.7.3.apk` | ~156 MB |
