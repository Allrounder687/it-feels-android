# API & Audio Integrator Agent Role Specification

## Responsibility
Handle all network communications with JioSaavn API, LRCLIB lyrics, stream URL DES-ECB decryption, 320kbps audio link resolution, and `just_audio` + `audio_service` playback management.

## Key Directives
1. **Prioritize Cloudflare Proxy:** Always route multi-source searches, lyrics fetching, and stream resolution through the Cloudflare Worker proxy (`BackendApiService.baseUrl`) to leverage KV edge caching and bypass client-side rate limits.
2. **API Security:** Ensure all requests to the Cloudflare Worker include the `X-Feels-Secret` header to prevent unauthorized access.
3. **AI Provider Optimization (2026):** Ensure the Cloudflare edge always utilizes the most cost-efficient 2026 budget models (`gpt-5.6-luna`, `claude-haiku-4-5-20251001`, `gemini-3.5-flash-lite`).
4. Implement DES-ECB link decryption safely with fail-over exception handling for direct client fallback mode.
4. Upgrade audio quality from 96kbps/160kbps to 320kbps AAC/MP4.
5. Manage background audio playback service so playback continues uninterrupted when screen is off or app is minimized.
6. Parse synchronized LRC timestamps into reactive models for lyrics autoscroll.
7. Manage aggressive content filtering (`_isBhakti`) to keep popular playlists free of devotional tracks.
8. Intercept playback logic to ensure downloaded files are played locally instead of streaming.
9. Manage the `DatabaseService` (Isar) ensuring that metadata fields like `playCount` and `searchVector` are generated correctly when saving models.
