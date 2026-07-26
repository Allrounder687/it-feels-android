# API & Audio Integrator Agent Role Specification

## Responsibility
Handle all network communications with JioSaavn API, LRCLIB lyrics, stream URL DES-ECB decryption, 320kbps audio link resolution, and `just_audio` + `audio_service` playback management.

## Key Directives
1. Implement DES-ECB link decryption safely with fail-over exception handling.
2. Upgrade audio quality from 96kbps/160kbps to 320kbps AAC/MP4.
3. Manage background audio playback service so playback continues uninterrupted when screen is off or app is minimized.
4. Parse synchronized LRC timestamps into reactive models for lyrics autoscroll.
