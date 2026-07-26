---
name: pixel-ui-design-skill
description: Guidelines and design system rules for replicating the PixelPlayer Material 3 Expressive UI in Flutter (Wavy seekbar, Dynamic album palette, Hero collage, Pill buttons).
---

# PixelPlayer UI & Design System Skill Guide

## 1. Aesthetic Principles
- **Vibrant & Muted Dark Themes**: Monochromatic & dual-tone dark themes (Dark Burgundy/Maroon `#2D1520`, Deep Midnight Blue `#0B1326`, Pure Charcoal `#121212`).
- **Material 3 Expressive Elements**: Pill-shaped containers (`BorderRadius.circular(28)`), smooth micro-animations, subtle glassmorphism overlay.
- **Dynamic Color Extraction**: Extract primary, surface, and container colors from active album artwork using `palette_generator`.

---

## 2. Wavy / Squiggly Seekbar Implementation (`WavySeekBar`)

### Custom Painter Concept
- Compute progress fraction: `progress = currentPosition / totalDuration`.
- Active segment (0.0 to progress): Draw a Sine wave path (`sin(x * frequency + phase) * amplitude`).
- Inactive segment (progress to 1.0): Draw a straight smooth line or dampened wave.
- Thumb indicator: Draw a smooth rounded pill / circle thumb at the boundary between active wave and inactive line.

```dart
class WavySeekBarPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double amplitude;
  final double waveLength;

  WavySeekBarPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.amplitude = 4.0,
    this.waveLength = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Render active wavy path and inactive line path
  }

  @override
  bool shouldRepaint(covariant WavySeekBarPainter oldDelegate) => true;
}
```

---

## 3. Screen Layout Guidelines

### Home / "Your Mix" Screen
- **Hero Title**: Bold display font ("Your Mix") with subtitle ("Today's Mix for you") and circular action play button.
- **Hero Artwork Composition**: Smooth rounded clipped card layout assembling album art tiles in an organic bubble silhouette.
- **Content Rows**: Horizontal scrolling cards for playlists, albums, and top charts.

### Now Playing Screen
- **Artwork Container**: Rounded rectangle (`BorderRadius.circular(24)`) with soft ambient drop shadow.
- **Control Bar**: Muted pill container holding Skip Prev, Play/Pause toggle, Skip Next buttons.
- **Bottom Bar**: Shuffle, Repeat, Heart (Like) pill action triggers.

### Library Screen
- **Filter Tabs**: `SONGS`, `ALBUMS`, `ARTIST`, `PLAYLISTS` horizontal pill filters with active underline highlight.
- **Action Pills**: `x Shuffle` and sort filter buttons.
- **Track Tiles**: Round artwork thumbnail, title, artist, trailing 3-dots action menu.

### Lyrics Screen
- **Header**: Back arrow, title, `Synced` vs `Static` toggle pill.
- **Scrolling Lyrics**: Auto-scrolling list view with active line highlighted in bold white (`fontSize: 20, fontWeight: FontWeight.bold`) and inactive lines muted (`opacity: 0.5`).
