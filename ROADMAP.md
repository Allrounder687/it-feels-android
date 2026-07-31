# IT Feels - Development Roadmap

This document outlines the planned architectural upgrades and features for the IT-Feels application, specifically focusing on the newly introduced Cloudflare Worker proxy engine.

## Cloudflare Worker Edge Expansion

### Phase 1: The Quick Wins (Backend Only) ✅
*Status: Completed*
These features require zero complex UI changes in the Flutter app, but provide massive performance and security upgrades.
- [x] **Edge Caching for Searches (KV)**: Setup a Cloudflare KV namespace and add caching logic to `index.ts` for lightning-fast zero-latency responses on repeated global search/lyrics queries.
- [x] **API Abuse Prevention**: Implement a custom `X-Feels-Secret` HTTP header check to protect the backend API from unauthorized scraping.
- [x] **Dynamic Image Proxy**: Route album artwork fetches through the Worker to set aggressive `Cache-Control` headers, allowing Cloudflare's global CDN to cache the binary data and save mobile bandwidth.

### Phase 2: Moderate Effort (Backend + App Updates) ✅
*Status: Completed*
These features require writing new logic in the Cloudflare Worker, as well as updating the Flutter app to send or receive new types of data.
- [x] **Moving AI Playlist Generation to the Edge**: Move the Ask Feels prompt logic from Dart to TypeScript. The Flutter app will call the Worker instead of calling Gemini/Claude directly. This keeps API keys 100% secure at the edge and prevents reverse-engineering.
- [x] **Custom "Trending on IT-Feels" Charts**: Set up Cloudflare Analytics Engine. The Flutter app will send a tiny background telemetry ping to the Worker every time a song finishes playing, allowing the Worker to aggregate and generate a real-time "Global Top 50" chart unique to the app.

### Phase 3: Major Features (Full Stack Projects) 🔴
*Status: Planned*
These are massive features that act as standalone projects. They require setting up databases, managing complex state, and building brand new UI screens in Flutter.
- [x] **Serverless User Accounts & Cloud Sync**: Set up Firebase backend to store user profiles, custom playlists, and favorite tracks. Built Auth screens with 0 cognitive overload.
- [x] **"Listen Together" (Firebase RTDB)**: Built a highly complex real-time synchronization engine and UI in the Flutter app to allow friends to connect to a "room" and listen to the same song perfectly synced.

### Phase 4: Social Audio & Real-time Expansions 🔴
*Status: Planned*
Taking the existing Listen Together sync engine and expanding it into a full social suite.
- [ ] **Live Voice Chat (Walkie Talkie)**: Integrate WebRTC/Agora to allow friends to talk over the music with automatic audio ducking.
- [ ] **Collaborative DJ Queue**: Allow guests in a sync room to add songs to a shared "Up Next" queue.
- [ ] **Interactive Sync Rooms**: Add floating emoji reactions (Instagram Live style) and real-time synchronized lyrics (karaoke mode) for all users in the room.
