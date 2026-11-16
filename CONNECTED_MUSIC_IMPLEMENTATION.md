# Connected music accounts

Implemented in the clean upstream app. Connect an account from Home, Settings → Connected music, or the desktop Connected Music destination. There are no playlist transfers, pasted links, API keys, or cookie-copying steps in the user flow.

## Architecture

- `lib/features/connected_music/`: account models, lifecycle service, native browser gateway, Riverpod bindings, and progressive queue ownership.
- `assets/account_addons/`: separately installed YouTube Music and Spotify readers. Clicking Connect installs the bundled addon. Service-specific URLs, requests, authentication checks, response parsing, and continuation logic stay in these scripts. The YouTube addon can also request session-granted direct audio; it performs no cipher or DRM decoding. See `CONNECTED_MUSIC_FIX_REPORT.md` for the performance and audio recovery update.
- `lib/features/new_experience/connected/`: responsive account cards, real service sign-in pages, automatic home shelves, and remote playlist detail.
- Account sessions are scoped to their service and stored with `flutter_secure_storage`. Windows uses a separate WebView2 profile per service. macOS uses the OS Keychain without requiring additional distribution provisioning for Keychain Sharing. iOS retains its existing App Group and adds the corresponding Keychain access group.
- Only playlist display metadata is cached in SharedPreferences. Cookies, passwords, bearer tokens, and raw service responses are excluded from that cache and from application logs. The WebView also maintains its normal platform cookie store.
- Background browsers have user-gesture-only media playback: they read account metadata and do not play audio. At most two readers run concurrently. Playback continues through the existing addon-based resolver and audio engine; no engine migration was performed.

## Behavior

After a verified sign-in, the feed refreshes automatically. Cached shelves appear on a subsequent launch while the remote refresh runs. Refreshes also run on app resume, every 15 minutes while the service is alive, and on Home pull-to-refresh. Overlapping requests coalesce. Transient failures retain the current view and retry after 30, 60, 120, and 240 seconds. Expired sessions expose Reconnect.

Successful full refreshes apply additions, deletions, ordering, artwork, and title changes. Partial refreshes never overwrite the complete persisted snapshot. Disconnect invalidates in-flight work before removing metadata, secure sessions, and service cookies. Per-account serialized storage operations prevent a late cache write from resurrecting disconnected data.

Playlist pages publish progressively. A playback subscription remains alive after the detail screen closes. It appends later pages only while the queue still matches that listening session. User queue replacement, removal, reordering, or shuffle relinquishes that ownership. Repeated recordings retain independent playlist-entry and queue identities.

## Provider details and limits

YouTube Music reads the signed-in library and a bounded sample of personalized home recommendations using the service's browser context. Library and playlist continuations are followed. Unknown response structures, repeated continuation tokens, service errors, and bounds are surfaced as incomplete/error states rather than empty success.

Spotify observes the official web player's authentication on-device, verifies it against the account profile, and reads playlist metadata. Where playlist-item access is restricted, the reader consumes playlist responses loaded by the official playlist page and advances its scroll viewport. This fallback depends on Spotify's current page schema, network transport, and virtualization. It requires a known total to report a complete playlist; it does not silently claim completeness from a few visible rows. The parser supports deleted/unavailable items and retains repeated recordings.

Readers have a two-minute operation deadline and explicit page/item bounds. This is a long-playlist implementation, not a guarantee of an infinite radio queue. Playback availability and matching behavior are inherited from installed audio addons. A Spotify connection does not supply decrypted Spotify audio. Provider changes may require an addon update or reconnect, and providers may reject embedded sign-in for some accounts.

## Verification

Run `python tool/verify_connected_music.py` for the expanded suite: 117 Dart checks and 29 synthetic addon-reader checks. The helper downloads Google Fonts to the ignored build directory for a readable rendered preview at `build/connected_music_preview.png`; normal Flutter test execution does not require that helper or font downloads. The discovery, long-mix, chapter fallback, and collection-download extension is documented in [DISCOVERY_MIXES_AND_DOWNLOADS.md](DISCOVERY_MIXES_AND_DOWNLOADS.md).

Coverage includes anonymous login rejection, cached startup, corrupt snapshots, freshness/coalescing, curator changes, partial and failed refreshes, account switching, two-service isolation, disconnect during network work and pending writes, origin validation, repeated recordings, continuation failures, profile verification, Spotify web-page fallback, and 320/768/1440px layouts at 100%/200% text scale.

All 49 focused tests passed, along with the existing 9 listening-collection regressions. Full `dart analyze lib/` reported no issues. The Windows debug build passed. The native smoke test (`flutter test integration_test/connected_music_native_test.dart -d windows --no-pub`) also passed, verifying the real OS secure store, cookie manager, and headless WebView2 JavaScript bridge with synthetic data. The project bootstraps a checksum-pinned NuGet CLI in its build tree for WebView2 dependencies. Native build output includes third-party WebView2/CMake and Firebase debug-symbol warnings.

**Not verified with a real signed-in account:** Google/Spotify acceptance of the embedded login, individual account consent/region restrictions, production library response shapes, large live playlists, real cross-provider audio matching, and reconnect after real expiry. Synthetic tests and compilation must not be described as end-to-end account certification. Android/iOS/macOS native builds have not been run in this Windows environment.

## Inspiration and reuse

Original implementation informed by [Metrolist](https://github.com/MetrolistGroup/Metrolist), [SimpMusic](https://github.com/maxrave-dev/SimpMusic), and [Spotube's plugin architecture](https://docs.spotube.cc/getting-started/). No GPL/AGPL application source was copied into this codebase. These are independent service integrations, not platform-approved APIs; addon isolation does not itself establish permission under service terms.

For downstream synchronization after committing and publishing upstream changes, run `git pull upstream master` from the `IT-Feels` directory.
