# Discovery, long mixes, and collection downloads

## Listening without a taste profile

The Home discovery section searches installed music repositories for real playlists and tracks across six starting points: global pop, Bollywood, Punjabi, indie/acoustic, chill/focus, and golden classics. A diverse sampler and Surprise me offer immediate starting queues. Surprise me uses the existing discovery orchestrator and validated catalogue results; it needs no new AI key and does not invent recordings.

The bundled YouTube account addon also discovers public playlists and long mixes without requiring a saved library. Public discovery is separate from private account shelves. Only public descriptors enter its cache. Cached results appear on startup; refreshes coalesce and run on resume, pull-to-refresh, and a six-hour schedule. Previous results survive transient failures. Availability still depends on providers, region, network, and installed playback addons.

## One video containing many songs

Long mixes have their own detail controls. The addon reads video identity, duration, native chapter markers, and timestamped description track lists. Provider-specific requests remain in the addon, outside the Dart app.

The full-mix path requests an audio-only source through the installed resolver. Explicit audio sources take priority; ambiguous sources receive a bounded MIME probe. Video-only sources do not qualify. There is no video transcoding or relabeling a video file as MP3.

When full audio is unavailable, Build track playlist resolves chapter titles against real catalogue tracks with bounded concurrency. Matching checks title, artist, recording variant, and plausible duration. Missing or generic chapter names remain unmatched. The interface displays match counts and individual unavailable entries; it does not claim a complete track list when the creator supplied none. Native chapter metadata takes precedence over description timestamps.

Matched tracks keep chapter order and repeated recordings. The saved playlist has a stable video-based ID, so rebuilding updates it rather than creating duplicates. Chapter controls seek within the complete mix, and the matched playlist supports normal playback and downloads. A later user playback selection takes precedence over an older asynchronous mix resolution.

## Download controls and queue

Shared download controls cover discovery cards, ordinary/custom/daily/generated playlist details, connected playlist details, long mixes, albums, artist top tracks, listening stations, see-all song collections, AI discovery results, and individual new-experience song tiles.

Collection downloads wait for complete remote pagination. A serial queue exposes progress, cancellation, partial failures, and retries. Duplicate clicks share a job. Saved files are skipped; repeated playlist recordings share one physical download. A failed-track retry refreshes its source URL before retrying. One failed track does not prevent later tracks or collections from downloading.

Jobs survive screen navigation while the app process is alive. Pending jobs are not persisted across process termination. Downloaded files use the existing offline library and remain available after restart; pressing Download again skips completed files. Cancellation finishes the current file and prevents new files from starting.

## Architecture and verification

This work stays in the clean upstream app. Account-specific metadata readers live in addon assets, audio resolution stays delegated to installed addons, and the audio engine is unchanged. Connecting Spotify supplies metadata, not decrypted Spotify audio. A visible Download control cannot guarantee that an installed provider can supply every recording.

`python tool/verify_connected_music.py` runs 95 Dart service/widget/regression checks and 25 synthetic JavaScript reader checks. These cover anonymous discovery, long-mix parsing, chapters and timestamps, incomplete metadata, audio selection, video-only fallback, stable saved playlists, retries, and narrow/large-text layouts. All 120 checks passed for this iteration. Full `dart analyze lib/` reported no issues, and the final Windows debug build passed. See `build/discovery_final_analysis.log`, `build/discovery_complete_verification.log`, and `build/discovery_mix_windows_final.log`.

Android debug compilation was attempted, then retried with a 2 GB Gradle heap, two workers, and only ARM64. The check was stopped during concurrent release-build memory pressure (about 270 MB free system RAM); no new Android APK is certified by this iteration. The separate release build was left running. Android compilation therefore remains unverified, rather than a passing build result.

Live Google/Spotify login, current production response shapes, regional access, and real installed-addon audio endpoints remain unverified. Fixture tests and successful builds are not live-provider certification.
