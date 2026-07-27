# AI Agents Log
This file tracks major technical decisions, features implemented, and architecture shifts guided by AI agents.

## Latest Agent Iteration
|- **Model Updates for IT Feels AI Provider:** Upgraded ChatGPT from `gpt-4o-mini` → `gpt-5-mini-2025-08-07`, Claude from `claude-3-5-haiku-20241022` → `claude-haiku-4-5-20251001`, and Gemini from `gemini-1.5-flash` → `gemini-2.5-flash` for significantly better price/performance ratios in playlist generation features.
- **Audiophile DSP Integration:** Implemented toggle controls for AndroidEqualizer and AndroidLoudnessEnhancer within Settings, bypassing complex manual slider UX for zero cognitive overload.
- **Bitrate Badges:** Enhanced Now Playing screen to dynamically show LOSSLESS, HIGH-RES, or 320 KBPS badges by parsing the media stream extension.
- **Gapless Playback Migration:** Switched from individual setUrl to ConcatenatingAudioSource for true gapless transitions.
- **Dynamic Theming Integration:** Refactored AudioPlayerProvider to calculate and broadcast Material You ColorSchemes derived from HomeWidgetProvider background processes and just_audio streams.
- **Android Integrations:** Added home_widget implementation in native Kotlin (MusicWidgetProvider.kt), managed namespace mismatches, and prepared Android Auto manifest entries.
- **Ask Feels Branding:** Renamed AI system to "Ask Feels" with conversational UX ("What are you feeling like?").
- **Build Isolation:** Configured debug builds with unique `applicationIdSuffix` and `appName` for parallel release/debug installations on user devices.
- **Dynamic Edge-to-Edge Padding:** Removed hardcoded safe areas in favor of `MediaQuery.viewPadding.bottom`, dynamically adapting the UI to any Android system navigation bar height.
- **Layout Exception Hotfixes:** Replaced raw `DecoratedBox` implementations around `ListTile`s with `Material` to resolve underlying layout crash vectors.
- **UX Polish:** Implemented Haptics via vibration on player controls, adjusted bottom navigation size, and added tap-to-seek lyrics.

## Agent Directives (Rules)
- **Version Management:** Whenever compiling a new debug or release build for the user, ALWAYS check `CHANGELOG.md` and bump the `version` property in `pubspec.yaml` (e.g., from `1.0.0+1` to `1.0.1+2` or whatever the next logical/changelog version is) before running the build command. This ensures the output APKs and binaries always have accurate, incremental version tagging.
- **Responsive & Edge-to-Edge Design:** ALWAYS wrap top-level layout boundaries or floating widgets in `SafeArea` to respect system insets (notches, status bars, and navigation pills). NEVER hardcode fixed heights/widths for containers meant to fill the screen; instead use `Expanded`, `Flexible`, `LayoutBuilder`, or relative `MediaQuery.of(context).size` values to guarantee flawless adaptation across all Android form factors.
