# PROJECT OBSIDIAN — COMPREHENSIVE PRODUCT AUDIT
**IT Feels Music — Enterprise Product Transformation 2026**
*Document Version: 1.0.0 | Status: Completed Forensic Audit & Prioritized Backlog*

---

## 1. Executive Summary

Project Obsidian represents an uncompromising elevation of IT Feels Music into a commercial-grade, world-class music streaming platform. This forensic audit examines every tier of the existing codebase (`c:\Users\Achie\kiro-projects\it-feels-android`), assessing playback fidelity, state synchronization, local indexing, search latency, UI ergonomics, and cross-platform capabilities.

**Strict Architectural Invariants Enforced:**
1. Zero AI assistants, chatbots, or synthetic engagement gimmicks.
2. Zero social feeds, follower counts, comments, or gamification loops.
3. Every feature and optimization directly serves the core music-listening experience.
4. Total preservation of the Classic UI.
5. All new UX, interactions, and design systems reside strictly inside the New Experience (`lib/features/new_experience/`).
6. Dual-codebase compliance: upstream clean addon repository preserved.

---

## 2. Forensic Audit by System Component

### 2.1 Audio Playback Engine & Media Pipeline
- **Underlying Engine:** `media_kit` (libmpv backend) wrapped by `AudioPlayerHandler` and `AudioEngineService`, coordinated by Riverpod's `AudioPlayerNotifier`.
- **Identified Weaknesses:**
  1. *Pseudo-Random Shuffle Defect:*
     `AudioPlayerNotifier.skipToNext()` selected random track indexes with replacement (`Random().nextInt(queue.length)`). In a 30-track playlist, tracks frequently repeated within 3 skips, and `skipToPrevious()` failed to retrace the true historical playback path.
  2. *Gapless & Preloading Gaps:*
     While `_preloadQueueLyricsAndMedia()` pre-warmed URLs, track transitions stopped the player and re-opened new `Media`, introducing a brief buffer gap rather than an uninterrupted gapless transition.
  3. *Crossfade Implementation Deficiency:*
     Crossfade was simulated as a blocking volume step-down loop (`_fadeOut()`) followed by song loading, resulting in a silent pause between tracks rather than an overlapping acoustic crossfade.
  4. *Aggressive Scrubber Seeking:*
     `NewNowPlayingScreen` passed continuous slider drag updates directly to `notifier.seek()` without debouncing, hammering the underlying audio pipeline during seeking and causing playback desynchronization.
  5. *Audio Interruptions & Transient Ducking:*
     `AudioSession` handled headphone disconnection, but lacked automatic transient volume ducking during navigation prompts or notification chimes on mobile platforms.
  6. *Equalizer & Audio DSP Limitations:*
     `AudioEngineService.setDspEngine()` applied hardcoded static EQ frequencies (`f=64:g=5, f=4000:g=3`). The application lacked a user-tunable 10-band Graphic Equalizer, sound presets (Flat, Bass Boost, Rock, Pop, Jazz, Acoustic, etc.), and custom user curves. Furthermore, legacy UI text erroneously claimed EQ was exclusive to Android hardware.
  7. *Lack of Volume Normalization (ReplayGain / LUFS):*
     Varying track loudness across older masterings and modern productions caused jarring volume discrepancies between consecutive tracks.

### 2.2 Music Library & Local Data Store
- **Underlying Storage:** Dual-layer architecture: Isar NoSQL database (`it_feels_db`) for high-volume song models and caching, combined with `SharedPreferences` for user playlists and settings.
- **Identified Weaknesses:**
  1. *Sparse Library Organization:*
     `NewLibraryScreen` presented a basic "Liked Songs" banner and download list, lacking multi-criteria sorting (Alphabetical, Artist, Date Added, Most Played, Duration).
  2. *Absence of In-Library Search:*
     Users could not quickly filter their saved songs or downloads in real time within the library screen.
  3. *Missing Bulk Management:*
     No multi-select mode existed to bulk-add songs to custom playlists, bulk-download albums, or bulk-remove tracks.
  4. *Unsurfaced Analytics:*
     High-value local data like "Most Played" and "Recently Played" existed in Isar/StorageService but were not integrated into the Library workflow.

### 2.3 Search Engine & Catalogue Resolution
- **Underlying Architecture:** JioSaavn primary REST API with Cloudflare Edge proxy fallback.
- **Identified Weaknesses:**
  1. *Isolated Local vs. Online Search:*
     Search queries queried only the online catalogue. Offline tracks and user-created playlists were ignored, resulting in zero results when disconnected from the internet.
  2. *Lack of Search History & Fast Queries:*
     No persistent recent search chip shelf with quick-clear capability.
  3. *Zero Typo Tolerance:*
     Minor typos in artist or track names yielded empty result sets.

### 2.4 User Interface & Interaction Design
- **Underlying Design System:** Obsidian New Experience tokens with `NewAmbientCanvas` dynamic mesh gradients.
- **Identified Weaknesses:**
  1. *Now Playing Screen Usability:*
     Missing in-screen volume slider and quick mute on mobile; scrubber lacked floating timestamp tooltip during scrubbing.
  2. *Equalizer UI Missing in New Experience:*
     No modern Obsidian-styled Equalizer and DSP modal sheet in the New Experience.
  3. *Contextual Menus & Quick Actions:*
     Song options sheets required more ergonomic tap targets and quick playlist addition workflows.

---

## 3. Prioritized Project Obsidian Implementation Roadmap

```text
+-----------------------------------------------------------------------------------+
|                        PROJECT OBSIDIAN EXECUTION ROADMAP                         |
+-----------------------------------------------------------------------------------+
|  PHASE 1: Playback Reliability & Audio Pipeline Overhaul                          |
|  - Fisher-Yates Shuffled Playlist Engine with Bi-Directional History Stack        |
|  - High-Precision Scrubber Controller with Drag Debouncing & Instant Feedback     |
|  - Genuine 10-Band Graphic Equalizer + Bass/Treble Controls + 10 Presets (libmpv) |
|  - ReplayGain / Loudness Normalization via libmpv loudnorm filter                |
|  - Enhanced Audio Focus, Transient Ducking & Device Route Handling                |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|  PHASE 2: Library Architecture & Instant Multi-Source Search                      |
|  - In-Library Real-Time Search & Multi-Criteria Sorting Engine (A-Z, Date, Plays)  |
|  - Multi-Select Bulk Actions (Bulk Add to Playlist, Bulk Download, Bulk Delete)   |
|  - Unified Search: Local Library + Downloads + Playlists + Online Catalogue       |
|  - Search History Chips with Instant Replay & Single-Tap Pruning                 |
|  - Typo-Tolerant Acoustic Matching for Local Queries                             |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|  PHASE 3: Premium Obsidian UI & Sound Engineering Controls                        |
|  - Obsidian 10-Band Equalizer & Acoustic DSP Control Sheet                        |
|  - High-Precision Scrubber with Haptic Notches & Floating Timestamp Bubble        |
|  - Mobile Now Playing Ergonomics: Quick Volume Slider, Mute & Quality Indicators  |
|  - Polished Micro-Interactions, Smooth Transitions & Zero Overflow Layouts        |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|  PHASE 4: Quality Assurance, Benchmarking & Documentation                         |
|  - Automated Playback & State Transition Unit Tests                               |
|  - Compilation of All 10 Obsidian Technical Documentation Deliverables           |
|  - Static Analysis (dart analyze) & Regression Validation                         |
+-----------------------------------------------------------------------------------+
```
