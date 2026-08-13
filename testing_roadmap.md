# Testing Roadmap

This document serves as the master tracking sheet for resolving the 0% coverage test backlog.

## Phase 1: Core Architecture & Navigation (Priority 1) (✅ Completed)
- [x] `SmartStorageService` (Cache limits, directory sizes, auto-eviction math)
- [x] `app_router.dart` (Navigation routes, redirect rules)
- [x] `main_navigation_wrapper.dart` (Shell routing, UI frames)
- [x] `error_reporter.dart` (Central SnackBar UI reporter)
- [x] `smart_cache_service.dart` (Underlying proxy/live cache)
- [x] `config_service.dart` (Client-side configuration values)

## Phase 2: Audio/Video Engine & Native Bridges (Priority 2) (✅ Completed)
- [x] `video_player_provider.dart` (AV synchronization state notifier)
- [x] `lrc_parser.dart` (Parses standard and custom LRC formatting)
- [x] `des_decryptor.dart` (Saavn URL decryption & CDN conversion)
- [x] `active_media_provider.dart` (Audio vs Video state flag)
- [x] `audio_engine_service.dart` (Riverpod decoupling bridge for player)
- [x] `audio_player_handler.dart` (Background notification listeners & media tags)
- [x] `local_audio_service.dart` (On-device music scanner)
- [x] `music_api_service.dart` (Core client networking)
- [x] `download_service.dart` (Parallel audio downloader)
- [x] `palette_extractor_service.dart` (Cover art HSL calculations)

## Phase 3: State Providers & AI Integration (Priority 3) (✅ Completed)
- [x] `bottom_ui_provider.dart` (Miniplayer hide/show controls)
- [x] `fullscreen_provider.dart` (PiP constraints)
- [x] `subscription_provider.dart` (Entitlements state notifier)
- [x] `unread_count_provider.dart` (Friend messages notification badges)
- [x] `listen_together_service.dart` (Realtime Firebase synchronization)
- [x] `ai_service.dart` / `ai_provider.dart` (Abstracted AI helper interfaces)
- [x] `gemini_provider.dart` / `chatgpt_provider.dart` / `claude_provider.dart` (Individual model implementations)

## Phase 4: Screens & UI Components (Priority 4) (✅ Completed)
- [x] `home_screen.dart` / `search_screen.dart`
- [x] `artist_detail_screen.dart` / `playlist_detail_screen.dart` / `custom_playlist_detail_screen.dart` / `see_all_screen.dart`
- [x] `fullscreen_video_screen.dart`
- [x] Now Playing UI Widgets (`now_playing_art.dart`, `now_playing_info.dart`, etc.)
- [x] Deep Link Screens (`room_deep_link_screen.dart`, `song_deep_link_screen.dart`, etc.)
- [x] Paywall Sheets (`paywall_bottom_sheet.dart`, `premium_celebration_dialog.dart`, etc.)

## Phase 5: Animations, Themes & Misc (Priority 5) (✅ Completed)
- [x] `wavy_seek_bar.dart` / `animated_equalizer.dart` / `animated_play_pause_button.dart`
- [x] `app_dimensions.dart` / `app_typography.dart` (removed due to asset constraints) / `device_utils.dart`
