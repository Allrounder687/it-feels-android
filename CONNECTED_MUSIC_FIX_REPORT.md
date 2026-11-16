# Connected music: frame stalls and audio recovery

## Findings

The upgrade launched full music-site WebViews during feed startup, allowed two readers at once, and repeatedly serialized/decoded cumulative playlist snapshots. Detail views and downloads could start independent readers for the same playlist. Audio playback also eagerly prefetched video streams for several queued recordings.

Playback had separate failures. A live request to the installed backend returned HTTP 200 with `success: true` and an empty `streams` list. The transport guessed JSON versus audio from an `/api/` substring and required a redundant success flag. `Song.fromJson` also dropped valid provider-supplied `streamUrl` fields and assigned fabricated Saavn identities to restored Spotify records. Some international searches contain YouTube originals and catalogue covers, without a catalogue original; covers must not be silently substituted.

## Changes

- YouTube background readers open a tiny same-origin text document. The addon fetches configuration JSON without executing the music site's scripts. Interactive sign-in still uses the service's real page. Provider requests remain in addon JavaScript.
- One background reader runs at a time; queued playlist/audio work takes priority. Cancellation releases an unused reader. Startup refreshes are staggered and respect existing cache freshness. Catalogue discovery uses one worker.
- Unchanged snapshots do not cross the browser bridge. Track pages transfer only newly appended entries. Snapshot decoding and large playlist-cache encoding run on helper isolates.
- Detail views, playback continuation, and downloads share a replaying playlist request. Complete snapshots are reused for 15 minutes; retries explicitly invalidate freshness. Live refreshes replace deleted/reordered cached entries. Memory snapshots are bounded.
- Full playlist metadata lives in atomic cache files, capped at 32 entries/32 MB, rather than the general settings store. Legacy entries migrate on access. Reconnecting or disconnecting clears that service's cached playlist files without removing another service's cache.
- Audio prefetch no longer fetches video streams and is limited to one next recording once playback is active. A null resolution is not immediately repeated with identical inputs.
- The addon can request a direct audio URL granted by the current YouTube browser session. Actual network status/MIME is checked. Ciphered, DRM, and video formats are not decoded or guessed. Session audio is excluded from metadata persistence.
- Installed URL addons support extensionless audio and multiple JSON result shapes without requiring `success: true`. Empty results and explicit failures remain unavailable. Video containers do not become audio downloads.
- When original audio is unavailable, a bounded fallback searches installed catalogue providers for a matching recording. It checks title, credited artist groups, duration, and recording variants before deduplication. It never replaces a long mix with one unrelated song.
- Provider stream URLs and external identities survive JSON round trips. Signed-URL expiry and bounded stream-cache TTLs are respected. Concurrent playback/download requests share resolution.

## Verification

`python tool/verify_connected_music.py`: **117 Dart tests and 29 JavaScript checks passed**. Coverage includes large repeated-entry snapshots, shared readers, cache migration/bounds/account cleanup, refresh/removals, empty source responses, real repository fallback/coalescing, recording mismatches, composer-first credits, signed-URL expiry, session-audio selection, and responsive layouts.

Opt-in native check: `flutter test integration_test/connected_music_live_test.dart -d windows --no-pub --dart-define=VERIFY_CONNECTED_LIVE=true`. **Both live checks passed.** The updated public reader returned 56 playlist cards in about 12 seconds while Flutter rendered 623 frames; one debug-frame build exceeded 100 ms. The recording check reached an endpoint returning **HTTP 206, `audio/mp4`**, and canceled the media body. These are desktop debug observations, not phone performance benchmarks or full offline-download certification.

Logs: `build/connected_fix_complete.log`, `build/connected_fix_readers.log`, and `build/connected_fix_live_windows.log`. Native build and final analysis results are recorded separately in `build/connected_fix_android.log`, `build/connected_fix_windows_app.log`, and `build/connected_fix_analysis.log`.

Final checks: full `dart analyze lib/` reported **No issues found**. The normal Windows debug app and Android ARM64 debug APK both compiled successfully. `build/connected_fix_android_final.log` records the final incremental Android build, which includes the cache hardening. The worker-isolate cache I/O tests also passed in `build/connected_fix_file_io_final.log`.

No Android device is connected, so actual Android frame timings and physical-device playback remain unverified. Provider login/region restrictions and missing original recordings can still prevent a particular track from resolving. The app does not claim an empty backend response is playable.

## Sources checked

[InAppWebView's headless documentation](https://inappwebview.dev/docs/webview/headless-in-app-webview/) confirms that a headless view remains a WebView and requires disposal. [Flutter's isolate guidance](https://docs.flutter.dev/perf/isolates) describes moving expensive parsing off the UI isolate. [Metrolist's player entry point](https://github.com/MetrolistGroup/Metrolist/blob/main/app/src/main/kotlin/com/metrolist/music/utils/InnerTubeXPlayer.kt) informed separation of stream resolution from feed work. No application source was copied.

The [yt-innertube project](https://github.com/AlvaroBalbin/yt-innertube) describes an alternate public audio client. A read-only probe on this network returned `LOGIN_REQUIRED`, so that unverified client was not shipped as a guaranteed fix.
