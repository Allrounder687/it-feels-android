# IT Feels Music v3.7.2 — Sleek UI/UX & Cross-Platform CI Release

Maintenance and polish release delivering the complete Next-Gen Obsidian UI/UX overhaul, resolving CI/CD asset checks, upgrading Gradle dependencies, and stabilizing the multi-platform automated release pipelines.

---

### 🌟 Key Highlights

#### 1. 🎨 Next-Gen Obsidian UI/UX Modernization
- **Spotify-Grade Playlist Action Bar**: Replaced bulky multi-button text wraps with minimalist circular glass controls (Shuffle, Play Next, Add to Queue, Search) and an obsidian glowing circular Play FAB.
- **On-Demand Sleek Search**: Removed the permanent filter input box in favor of a smooth, collapsible on-demand search toggle.
- **Zero Truncated Titles**: Constrained button hit targets, dynamic 2-line title wrapping, and optimized horizontal padding ensure full song titles on all devices.
- **Streamlined Library**: Compact 36px filter chips, 32px quick actions, and a sleek 56px pinned Liked Songs card.

#### 2. 🎵 Playback Resilience Pipeline
- **AudioSession & Interruption Recovery**: Audio session initialized with `AudioSessionConfiguration.music()`, explicit `setActive(true)`, and interruption recovery handling.
- **2-Hour TTL Stream Cache**: Auto-eviction on 403 Forbidden CDN expiration prevents unplayable song freezes.
- **12-Second Network Watchdog**: Prevents background playback from stalling on dead network sockets.

#### 3. 🛠️ CI/CD & Build Pipeline Hardening
- **CI Asset Validation**: Resolved `.env` asset tracking in `pubspec.yaml` and `.gitignore`.
- **Inno Setup Output Name Alignment**: Harmonized installer artifact naming in `desktop_release.yml` with Inno Setup scripts.
- **Gradle 9.3.1 Compatibility**: Upgraded Gradle wrapper for seamless Shorebird and Android release builds.

---

### 📦 Artifacts in this Release

| Platform | Format | File Name | Size |
| :--- | :--- | :--- | :--- |
| **Windows** | Inno Setup Installer | `IT_Feels_Music_v3.7.2_Setup.exe` | ~40 MB |
| **Android** | Signed Release APK | `IT_Feels_v3.7.2.apk` | ~156 MB |
