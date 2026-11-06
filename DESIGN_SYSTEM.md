# IT FEELS MUSIC — DESIGN SYSTEM SPECIFICATION (2026 GENERATION)

## 1. Visual Identity & Brand Concept

The **2026 New Experience** introduces an authentic, luxury visual identity characterized by:
- Deep obsidian and midnight spatial surfaces with specular rim lighting.
- GPU-accelerated dynamic mesh background derived from album cover art.
- Ultra-refined editorial typography pairing Outfit (expressive headlines) and Inter (crisp UI body).
- True multi-device adaptive ergonomics adhering to the 3-tier progressive disclosure model and Steven Hoober thumb zones.
- 100% isolation from Classic UI tokens.

---

## 2. Color Palette & Semantics (`NewExperienceTokens`)

| Token Name | Hex Value | Purpose |
|---|---|---|
| `obsidianBackground` | `#08080A` | Deepest canvas background, energy-efficient on OLED |
| `midnightSurface` | `#121217` | Card, container, and drawer primary surface |
| `elevatedGlass` | `#1A1A22` | Frosted glass modals, popovers, and miniplayers |
| `specularBorder` | `rgba(255,255,255,0.08)` | 1px sub-pixel rim highlight on cards |
| `accentViolet` | `#8B5CF6` | Primary brand accent, glowing focus states |
| `accentCyan` | `#06B6D4` | Secondary accent, live lyrics & discovery badges |
| `accentEmerald` | `#10B981` | Downloaded indicators, audio streaming fidelity |
| `textPrimary` | `#F8FAFC` | High-contrast headlines and active titles (WCAG AAA) |
| `textSecondary` | `#94A3B8` | Subtitles, artist names, metadata |
| `textMuted` | `#64748B` | Timestamps, durations, inactive icons |

---

## 3. Typography Scale

- **Display Headline (Hero)**: Outfit 32sp, SemiBold / Bold, -0.8px letter spacing.
- **Section Title**: Outfit 20sp, Bold, -0.4px letter spacing.
- **Eyebrow Label**: Inter 11sp, ExtraBold, +1.2px uppercase tracking.
- **Primary Body**: Inter 14sp, Medium, normal spacing.
- **Secondary Caption**: Inter 12sp, Regular, muted tone.
- **Mono / Numeric**: Inter 13sp with tabular figures for seek timers & durations.

---

## 4. Geometry & Elevation

- **Card Squircle Radius**: `20.0` dp with continuous curvature.
- **Button Pill Radius**: `24.0` dp.
- **Dock / Floating Island Radius**: `28.0` dp.
- **Glass Refraction**: `BackdropFilter` with `ImageFilter.blur(sigmaX: 20, sigmaY: 20)`.
- **Specular Border**: `Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0)`.

---

## 5. Animation Curves & Reduced Motion

- **Micro-Interactions (Hover, Tap)**: `Curves.easeOutCubic`, 180ms duration.
- **Sheet / Drawer Transitions**: `Curves.easeOutQuint`, 350ms duration.
- **Mesh Palette Crossfade**: `Curves.easeInOutCubic`, 600ms duration.
- **Reduced Motion**: Automatically respected when `MediaQuery.of(context).disableAnimations` is `true`.
