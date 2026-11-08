# IT Feels Music v3.7.0 — Next-Gen Obsidian UI & Stability Release

A major milestone release introducing the complete **Next-Gen Obsidian UI**, resolving the critical Windows Firebase threading and Semantics crashes, adding the Anti-Chiptune / Emulation quality shield, and establishing production-grade Inno Setup packaging.

---

### 🌟 Key Highlights

#### 1. 🪟 Critical Windows Crash Resolution
- **Eliminated Native Threading Violations**: Created `WindowsSafeRtdb` to replace native C++ background `EventChannel` streams with message-loop compliant polling on Windows while preserving low-latency realtime streams on Android, iOS, macOS, and Linux.
- **Semantics Tree Stabilization**: Eliminated `SemanticsNode !child.attached` and `node.built` crashes by configuring `addSemanticIndexes: false` in `ScrollablePositionedList`, assigning stable `effectiveQueueKey`s in `ReorderableListView`, and deferring state mutations to post-frame callbacks.

#### 2. 🛡️ Anti-Chiptune / Emulation & Search Poisoning Shield
- **Eliminated 8-Bit/16-Bit Emulation Spoofing**: Added heuristic detection in `TrackValidationEngine` blocking chiptune covers (`Arcade Player`, `8-Bit Arcade`), sound-alike cover squatters (`Blue Pink`, `Hafizur Rahman`), and SEO title-stuffing in **Pop & International** (Daily Mix 2).
- **Curated Ingestion**: Upgraded feed seed queries to authentic studio pop hits (The Weeknd, Dua Lipa, Taylor Swift).

#### 3. 🎨 Next-Gen Obsidian UI Suite
- **Living Desktop & Mobile Experience**: Frosted glass containers, ambient mesh dynamic canvas, responsive contextual panel (Lyrics, Queue, Story), and desktop player bar with drag-buffered scrubbing.
- **Procedural Daily Mix Covers**: Generated high-contrast procedural vector covers for Daily Mixes 1–6 with custom vinyl groove painters and genre badges, eliminating blank grey placeholders.

#### 4. 🧠 Living Music Catalogue Engine
- **Variant-Preserving Deduplication**: Consolidates duplicate tracks across providers while strictly preserving remixes, live concerts, acoustic versions, and remasters.
- **Orthogonal Mood & Genre Intelligence**: Deterministic acoustic phoneme scoring across 9 emotional states and 10 musical traditions.

#### 5. 🔍 Deep Observability & Diagnostics Subsystem
- **Centralized Structured Logging**: Six-tier logging (`trace` to `fatal`) with automated privacy scrubbing (tokens, emails, secrets, Windows paths) and bounded rotating file sink.
- **Settings Diagnostics Observatory**: 5-tab developer dashboard for live telemetry and one-click JSON/Markdown diagnostic exports.

---

### 📦 Artifacts in this Release

| Platform | Format | File Name | Size |
| :--- | :--- | :--- | :--- |
| **Windows** | Inno Setup Installer | `IT_Feels_Music_v3.7.0_Setup.exe` | ~39.7 MB |
| **Android** | Signed Release APK | `IT_Feels_v3.7.0.apk` | ~154.2 MB |
