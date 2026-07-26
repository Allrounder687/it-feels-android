# Theming Strategy

This document outlines the theming strategy for the PixelPlayer Flutter application, focusing on its use of Material 3 principles, dynamic color extraction, and fixed color palettes.

---

## 1. Material 3 & Expressive UI

The application adheres to Material Design 3 (M3) guidelines, specifically leveraging the "Expressive" aesthetic. This is characterized by:
*   **Dynamic Color:** The UI can adapt its color scheme based on the content (primarily album artwork).
*   **Organic Shapes:** Use of rounded corners, pill-shaped containers, and fluid animations.
*   **Enhanced Typography:** Clear hierarchy and readable fonts.
*   **Depth and Surface:** Using subtle color variations instead of heavy shadows to define surfaces.

---

## 2. Dynamic Color Extraction

A key feature of PixelPlayer is its ability to extract a color palette from the currently playing song's album artwork and apply it to the UI in real-time.

**Implementation Details (`lib/providers/audio_player_provider.dart`):**
*   **Library:** Uses `palette_generator` to extract colors from the `coverArt` URL.
*   **Extracted Colors:**
    *   `dominantColor`: Used as the base for the background color.
    *   `darkMutedColor`: Used for surface and card colors.
    *   `lightVibrantColor`: Used as the accent color for buttons, progress bars, and highlights.
*   **Adjustments:** To ensure a consistent dark theme aesthetic and proper contrast, extracted colors are often converted to HSL and have their lightness adjusted (e.g., background lightness set to ~0.12, surface to ~0.18).

---

## 3. Fixed Color Palettes (`lib/core/theme/app_colors.dart`)

While dynamic color is a primary feature, the application also defines several fixed, high-quality dark themes used as defaults or for specific screens.

### A. Deep Burgundy / Maroon Theme
A rich, dark reddish-purple theme often used for a sophisticated look.
*   `burgundyBackground`: `0xFF220F19`
*   `burgundySurface`: `0xFF2C1622`
*   `burgundyAccent`: `0xFFF3C0D0`

### B. Deep Midnight Blue Theme
A deep, cool blue theme providing a calm and focused atmosphere.
*   `midnightBackground`: `0xFF090D16`
*   `midnightSurface`: `0xFF101726`
*   `midnightAccent`: `0xFFA5C0F3`

### C. Neutral Dark Theme
A classic dark theme using near-blacks and greys.
*   `darkBackground`: `0xFF121212`

---

## 4. Dark Mode Strategy

PixelPlayer is designed exclusively as a dark-themed application. There is currently no light mode implementation. This choice reinforces the "Pixel Expressive UI" aesthetic, which favors high contrast and vibrant accents against deep, dark backgrounds.

---

## 5. UI Components and Theming

Various custom and standard Material components are themed consistently:
*   **MiniPlayer:** A floating pill-shaped container that uses the `themeSurfaceColor` and `themeAccentColor`.
*   **WavySeekBar:** Its active color is tied to `themeAccentColor`, and its inactive color uses a semi-transparent white for a subtle look.
*   **Hero Collage:** Uses a mix of images and colors, often influenced by the active track's palette.
*   **Navigation:** Uses standard Material 3 navigation components with colors mapped to the current theme.

---

## 6. Future Enhancements

*   **User Theme Selection:** Allow users to manually choose between the fixed themes (Burgundy, Midnight, Neutral) or enable/disable dynamic color extraction.
*   **Dynamic Color Customization:** Provide more granular control over how dynamic colors are applied (e.g., choosing which palette color to use as the accent).
*   **Font Theming:** Further refine typography to better align with M3 Expressive styles.
