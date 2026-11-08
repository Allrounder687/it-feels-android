# Obsidian Design System & Interaction Specification
**IT Feels Music — Project Obsidian 2026**
*Document Version: 1.0.0 | Status: Production Design System Specification*

---

## 1. Design Philosophy

The Obsidian Design System is built to deliver a luxurious, immersive, and human-centric music listening experience. It avoids flat sterile minimalism in favor of subtle depth, rich dark materials, specular glass borders, dynamic atmospheric lighting, and tactile haptic feedback.

```text
+-----------------------------------------------------------------------------------+
|                            Obsidian Theme Tokens                                  |
|                                                                                   |
|  * Background:   #0A0A0C (Deep Space Obsidian)                                    |
|  * Surface:      #141418 (Frosted Midnight Surface)                               |
|  * Specular:     rgba(255, 255, 255, 0.08) (Subtle Edge Refraction)               |
|  * Accent Cyan:  #06B6D4 (Digital Cyan Indicator)                                 |
|  * Accent Violet:#8B5CF6 (Vibrant Violet Primary)                                 |
|  * Accent Rose:  #F43F5E (Heart & Favorite Rose)                                  |
+-----------------------------------------------------------------------------------+
```

---

## 2. Dynamic Ambient Canvas (`NewAmbientCanvas`)

Music is visual and emotional. The background of the New Experience is powered by `NewAmbientCanvas`:
- **Dynamic Color Extraction:** As a new track loads, `PaletteExtractorService` extracts dominant, surface, and complementary accent colors in a background isolate.
- **Radial Lighting Meshes:** Renders layered radial blur shaders centered behind album artwork with configurable intensity ($0.3$ on browse screens, $0.65$ on Now Playing).
- **GPU Efficiency:** Mesh gradients use static hardware shaders without continuous repaint loops, preserving device battery life during long listening sessions.

---

## 3. Typography Hierarchy

The design system unifies two premier typefaces:
- **Display & Section Titles:** `GoogleFonts.outfit()`
  - Bold, modern geometric sans-serif with tight character tracking ($-0.3\text{px}$).
  - Used for hero banners, song titles, artist names, and section headers.
- **Body & Metadata Typography:** `GoogleFonts.inter()`
  - Highly legible, neutral body font designed for optical readability on mobile and high-DPI displays.
  - Used for artist subtitles, album descriptions, lyrics, and metadata timestamps.
- **Numeric Timers:** Monospaced tabular numerals (`FontFeature.tabularFigures()`) preventing jitter in progress counters.

---

## 4. Components & Materials

### 4.1 Specular Glass Containers (`NewGlassContainer`)
- Backed by subtle white opacity ($0.04 - 0.08$) and ultra-thin white border refraction ($0.08 - 0.12$).
- Provides high contrast against dark backdrops without opaque visual weight.

### 4.2 Universal Artwork Image (`NewArtworkImage`)
- Resolves network URLs, local filesystem paths (`C:\...`, `/storage/...`), and `file://` URIs seamlessly.
- Enforces smooth anti-aliased squircle borders (`borderRadius: 20-28dp`).
- Displays animated placeholder skeletons during disk or network I/O.

### 4.3 High-Precision Scrubber (`NewAudioScrubber`)
- Local drag buffering preventing continuous stream seeks.
- Thumb enlarges from $6.0\text{dp}$ to $8.5\text{dp}$ when touched with subtle specular glow.
- Haptic notches trigger on minute boundaries.

---

## 5. Micro-Interactions & Haptics Matrix

| Action | Visual Animation | Haptic Feedback Tier | Audio Consequence |
| :--- | :--- | :--- | :--- |
| **Play / Pause Toggle** | Artwork scales between $0.94$ and $1.00$ ($300\text{ms}$ ease-out) | `HapticFeedback.mediumImpact()` | Immediate play / pause |
| **Favorite Track Toggle** | Rose heart pulse animation ($1.2\times$ bounce) | `HapticFeedback.lightImpact()` | Inserts / removes from favorites |
| **Scrubber Dragging** | Scrubber thumb expands, track height increases | `HapticFeedback.selectionClick()` on start; light tick on each minute | Seeks on touch release |
| **Skip Track (Next/Prev)**| Slide transition on track details | `HapticFeedback.lightImpact()` | Traverses shuffled / linear queue |
| **Equalizer Band Shift** | Gain numerical text changes color to cyan | Light impact per $3\text{dB}$ threshold | Adjusts biquad filter in real-time |
| **Multi-Select Toggle** | Checkbox fades in with cyan fill | `HapticFeedback.selectionClick()` | Adds / removes from selection set |
