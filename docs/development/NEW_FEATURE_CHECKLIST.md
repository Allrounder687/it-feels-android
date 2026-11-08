# IT Feels Music — New Feature Standard & Development Checklist

> **PROJECT OBSIDIAN ARCHITECTURAL STANDARD (v3.9.3)**
> This checklist governs all feature engineering in the `IT_Feels_Alternate` upstream codebase. Every pull request, subagent task, and feature addition must satisfy these gates prior to release.

---

## 1. Product Direction & Scope Boundaries
- [ ] **Music-First Focus:** Feature directly enhances listening, collection management, sound engineering, or catalog discovery.
- [ ] **No AI Assistants / Bots:** Absolutely zero LLM/conversational assistants or synthetic chatbots in the UI.
- [ ] **No Social Feeds / Gamification:** No follower feeds, comments, badges, streaks, or artificial retention loops.
- [ ] **Dual-Codebase Upstream Compliance:** Implemented strictly in `IT_Feels_Alternate`. Never write UI/OS code downstream in `IT-Feels`.
- [ ] **No Hardcoded Scraping APIs:** All catalog resolution delegates dynamically via addons or existing clean repositories. Never hardcode scraping dependencies.
- [ ] **Classic UI Preservation:** The classic interface (`lib/views/`) remains 100% functional and unmolested.

---

## 2. Playback & Action Standardization
- [ ] **Context-Aware Playback:** Any list of songs provides "Play All" and "Shuffle Play" (`shufflePlayContext`).
- [ ] **Queue Insertion:** Collections (albums, playlists, artist tracks) support "Play Next Batch" (`playNextBatch`) and "Add to Queue" (`addSongsToQueue`).
- [ ] **Song Options Standard:** Every song item exposes `SongOptionsSheet` on right-click (desktop) or long-press / trailing icon (mobile).
- [ ] **Cross-Entity Navigation:**
  - Clicking an artist name navigates to `NewArtistDetailScreen`.
  - Clicking an album title/art navigates to `NewAlbumDetailScreen`.
  - Song options sheet provides direct routes to Artist, Album, and Track Story & Credits.
- [ ] **Deterministic Shuffling:** Shuffling utilizes the deterministic Fisher-Yates shuffle engine in `AudioPlayerNotifier`, maintaining non-repeating traversal and backward history retracing.

---

## 3. UI, Layout & Responsive Standards
- [ ] **Obsidian Design Tokens:** All colors, typography, border radii, and blur filters derive strictly from `NewExperienceTokens`.
- [ ] **Dynamic Bottom Clearance:** Scroll views utilize `ContentViewportInsets.sliverBottomSpacer(context, ref)` or `ContentViewportInsets.bottom(context, ref)` to guarantee zero obstruction by floating MiniPlayer or mobile nav docks.
- [ ] **Touch & Pointer Ergonomics:** All touch targets maintain a minimum dimension of $44 \times 44\text{dp}$ ($48\text{dp}$ recommended for mobile).
- [ ] **Platform Adaptability:**
  - Desktop: Supports hover states, right-click menus, drag handles, and mouse scroll wheels.
  - Mobile: Supports swipe gestures, haptic feedback on boundary scrubs, and responsive modal bottom sheets.
- [ ] **Empty States:** Every list or collection provides a styled empty state with an informative title, subtitle, and primary call-to-action button.

---

## 4. Performance, Image & Memory Standards
- [ ] **Bounded Artwork Decodes:** All artwork rendering routes through `NewArtworkImage` with explicit `memCacheWidth` / `memCacheHeight` bounds ($64\text{px}$ to $800\text{px}$).
- [ ] **Repaint Boundaries:** Animated frequency bars, hover effects, and canvas lighting are insulated with `RepaintBoundary`.
- [ ] **Granular State Selection:** Riverpod watchers use `ref.watch(provider.select((s) => s.property))` to eliminate whole-tree widget rebuilds.
- [ ] **Off-Thread Compute:** Heavy disk I/O, regex parsing, and database transactions execute off the UI thread via `Isolate.run()` or background workers.

---

## 5. Offline & Network Fault Tolerance
- [ ] **Zero-Network Usability:** The feature does not crash, throw unhandled exceptions, or display permanent spinners when offline.
- [ ] **Companion Metadata Resolution:** Local or downloaded audio resolves metadata and artwork from companion files or cached records.
- [ ] **Circuit Breakers:** Remote queries route through exponential backoff with retry ceilings. Consecutive stream failures trip the circuit breaker after 3 attempts.

---

## 6. Machine-Readable Documentation & Testing
- [ ] **Feature Registry Updated:** Registered in `docs/architecture/feature_registry.json` under the appropriate domain.
- [ ] **Static Analysis Clean:** `dart analyze lib/ test/` reports **0 errors, 0 warnings, 0 lints**.
- [ ] **Automated Test Coverage:** Unit and/or widget tests created in `test/unit/` verifying happy-path, boundary conditions, and state mutations.
- [ ] **All Test Suites Passing:** 100% test pass rate across the full test runner.

---

## 7. Living Music Catalogue & Content Quality Standards
- [ ] **Genuine Catalogue Data:** No fake artists, synthetic albums, or gibberish placeholder collections.
- [ ] **Artwork Integrity & Fallbacks:** Every collection, mix, or album provides verified high-res artwork or deterministic quad-composite cover generated via `ArtworkRepairService`. Never displays a broken image or blank black card.
- [ ] **Global Deduplication:** Tracks and albums filtered through `CatalogueDeduplicationEngine` to eliminate identical duplicates while strictly preserving legitimate variants (live, remixes, acoustic, remasters).
- [ ] **Mood & Genre Discipline:** Classifications derived through `MoodGenreIntelligenceService`, strictly segregating emotional states (moods) from musical traditions (genres).
- [ ] **Content Health Registration:** All new content sections and feeds register and audit themselves in `ContentHealthService`.
- [ ] **Cold-Start Persistence:** Dynamic collections, Daily Mixes, and feed snapshots survive application restarts without empty flashes.

---

## 8. Deep Observability, Structured Logging & Diagnostics Standards
- [ ] **Structured Logging Interface:** Emits structured events via `ObservabilityService` with appropriate severity levels (TRACE, DEBUG, INFO, WARN, ERROR, FATAL) instead of raw `print` or `debugPrint`.
- [ ] **Correlation ID Propagation:** Operations propagating across multiple decoupled layers (UI $\rightarrow$ Provider $\rightarrow$ Repository $\rightarrow$ Engine) receive and attach a shared `correlationId`.
- [ ] **Automated Privacy Scrubbing:** Ensures zero logging of authentication tokens, Bearer headers, passwords, email addresses, personal filesystem paths (`C:\Users\[USER]\...`), or signed stream CDN tokens.
- [ ] **Failure Taxonomy & Actionable Codes:** Errors emit standardized machine-readable error codes (e.g. `ERR-PLBK-XXX`, `ERR-NET-XXX`, `ERR-DB-XXX`) accompanied by sanitized error messages and stack trace snippets.
- [ ] **Performance & Latency Telemetry:** High-latency operations (search, database queries $>50\text{ms}$, network requests $>1200\text{ms}$) record execution duration for p50/p95/p99 tracking in `PerformanceTelemetryTracker`.
- [ ] **Diagnostics Dashboard & Export Compatibility:** Critical state and diagnostic metrics are discoverable in `DiagnosticsDashboardScreen` and bundled into `DiagnosticExportService` archives.
