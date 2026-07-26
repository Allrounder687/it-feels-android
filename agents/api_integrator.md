# API & Audio Integrator Agent Role Specification

## Responsibility
Handle all network communications with JioSaavn API, LRCLIB lyrics, stream URL DES-ECB decryption, 320kbps audio link resolution, and `just_audio` + `audio_service` playback management.

## Key Directives
1. Implement DES-ECB link decryption safely with fail-over exception handling.
2. Upgrade audio quality from 96kbps/160kbps to 320kbps AAC/MP4.
3. Manage background audio playback service so playback continues uninterrupted when screen is off or app is minimized.
4. Parse synchronized LRC timestamps into reactive models for lyrics autoscroll.
5. Manage aggressive content filtering (`_isBhakti`) to keep popular playlists free of devotional tracks.
6. Intercept playback logic to ensure downloaded files are played locally instead of streaming.
7. Manage the `DatabaseService` (Isar) ensuring that metadata fields like `playCount` and `searchVector` are generated correctly when saving models.
