# IT Feels Music — Feature Context Capability Matrix
**Project Obsidian — Phase 4: Application-Wide Feature Completeness & Standardization**  
*Document Version: 3.9.3 | Target: Clean/Addon Upstream (IT_Feels_Alternate)*

---

## 1. Context Capability Overview

This matrix establishes the comprehensive feature availability across all entity contexts within **IT Feels Music**. 

Every context must meet or exceed these standardized capabilities to prevent functional regressions.

---

## 2. Definitive Capability Matrix

| Feature / Capability | Individual Track | Album Context | Artist Context | Custom Playlist | Downloaded / Offline | Search Results | Queue Context |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Play Sequential** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Shuffle Play (Fisher-Yates)** | N/A | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Play Next (Batch / Single)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| **Add to Queue** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| **Add to Custom Playlist** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Download for Offline** | ✅ | ✅ | ✅ | ✅ | 🔄 *(Remove)* | ✅ | ✅ |
| **Go to Artist Detail** | ✅ | ✅ | N/A | ✅ | ✅ | ✅ | ✅ |
| **Go to Album Detail** | ✅ | N/A | ✅ | ✅ | ✅ | ✅ | ✅ |
| **View Track Story & Credits** | ✅ | N/A | N/A | ✅ | ✅ | ✅ | ✅ |
| **Drag & Drop Reordering** | N/A | N/A | N/A | ✅ | N/A | N/A | ✅ |
| **Multi-Select Bulk Actions** | N/A | N/A | N/A | ✅ | ✅ | N/A | N/A |
| **Individual Track Removal** | N/A | N/A | N/A | ✅ | ✅ | N/A | ✅ |
| **Clear All / Clear Context** | N/A | N/A | N/A | ✅ *(Delete)* | ✅ *(Clear All)* | N/A | ✅ *(Clear)* |
| **Rename / Duplicate** | N/A | N/A | N/A | ✅ | N/A | N/A | N/A |
| **Synchronized Lyrics** | ✅ | N/A | N/A | ✅ | ✅ *(Offline)* | ✅ | ✅ |
| **Disk Storage Footprint** | N/A | N/A | N/A | N/A | ✅ | N/A | N/A |
| **Rescan Disk Storage** | N/A | N/A | N/A | N/A | ✅ | N/A | N/A |
| **Verified Quality Badge** | ✅ | N/A | N/A | ✅ | ✅ | ✅ | ✅ |

---

## 3. Platform Interaction Matrix

| Interaction Type | Windows / Desktop | Android / Mobile | iOS / Tablet |
| :--- | :--- | :--- | :--- |
| **Primary Tap / Click** | Play track or open entity | Play track or open entity | Play track or open entity |
| **Secondary Tap / Context** | Right-click mouse opens `SongOptionsSheet` | 3-dots icon opens `SongOptionsSheet` | 3-dots icon opens `SongOptionsSheet` |
| **Long Press** | N/A (Right-click preferred) | Opens `SongOptionsSheet` | Opens `SongOptionsSheet` |
| **Drag & Drop** | Mouse drag on reorder handle | Touch drag on reorder handle | Touch drag on reorder handle |
| **Hover Feedback** | Background highlight & pointer cursor | N/A | N/A |
| **Keyboard Hotkeys** | Space (Play/Pause), Alt+Left (Back), Alt+Right (Next), F (Search) | Hardware volume & media buttons | Hardware volume & media buttons |
| **Haptic Feedback** | N/A | Vibrates on scrubber whole-minute notches & drag starts | Taptic engine on scrubber notches |

---

## 4. Verification Compliance

- **Audit Completion:** 100% of capabilities in the matrix are backed by verified Dart implementations in `lib/`.
- **Regression Guard:** Regression test suite `test/unit/standardization/feature_completeness_test.dart` validates context mutation safety.
