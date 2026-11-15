# New UI, discovery and artwork audit

Date: 2026-11-16. Scope: this clean upstream checkout only.

## Implemented

- Home now exposes 66 cold-start collection definitions: 12 artist mixes, 26 years (current year back through 25 previous years), seven decades, nine moods and 12 genres. These are queries, not claims of preloaded or verified editorial playlists. Additional artist, album and song-radio collections come from available listening history and home tracks.
- Artist pages have a Dynamic Mix destination. Song options in the new experience have Start Song Radio, which requests recommendations through `IMusicRepository` and preserves the seed at the front of the queue.
- Collections resolve on demand through installed addons. No music provider API, scraper, streaming engine or credentials were added. A collection can legitimately be empty if its addon supplies no matching results.
- Non-album collections select up to 40 shuffled tracks from up to 60 candidates. Explicit refresh changes the first track when multiple tracks are available. The ordering remains stable for 12 hours between opens; refresh also fetches fresh candidates. This is random selection, not a collaborative recommendation model.
- Year/decade collections filter returned year metadata; artist and album collections filter identity fields. Quality validation and canonical title/artist deduplication use the existing validation engine. Missing or inaccurate addon metadata limits coverage, especially release year, which the existing Song model defaults to 2024 when absent.
- Cache snapshots preserve addon IDs, coalesce simultaneous requests, recover from individual corrupt snapshots, retain previous tracks during outages and cap stored collections at 80. Offline snapshots cache metadata, not audio downloads.

## Layout findings and fixes

| Area | Finding | Change |
| --- | --- | --- |
| Collection cards | Play controls appeared only on hover; card gestures lacked keyboard focus | Persistent play control and focusable InkWell |
| See All | Fixed card width differed from grid cell width; fixed ratio squeezed enlarged captions | LayoutBuilder card sizing and text-aware row extent |
| See All header/actions | Count and title competed horizontally at 320px/200% text; action pills competed for width | Stacked heading/count and wrapping actions |
| Home | Fixed carousel/filter heights ignored larger text | Text-scaled shelf and filter height |
| New collection shelves and grids | Need independent sizing for phones, tablets and wide desktops | Width-based columns, text-aware captions, scrollable shelves, safe areas |
| Full player | A single non-scrollable column could lose controls in landscape or short windows; narrow transport row squeezed | Scrollable minimum-height canvas and reduced padding below 360px |
| Equalizer | Header and booster labels overflowed; ten bands competed for phone width | Stacked header/labels, wrapping response actions, horizontally scrollable band controls |
| Search | Result headings competed with controls; genre cards and filters ignored enlarged text | Flexible headings and text-aware heights |
| Hits | Fixed action row could overflow with larger labels | Wrapping actions |
| Song rows | Index, artwork, duration and action buttons could consume all width in narrow/selection lists | Hide secondary index/duration below 360px while preserving actions |
| Desktop shell | Expanded sidebar plus 360px contextual panel squeezed the main viewport near 1024px | Automatically collapse sidebar with panel open below 1320px |

The remaining screen families were inspected at source level: Library, album/artist/playlist details, Track details, Explore, Music DNA, AI discovery, import, Settings, diagnostics, mini-player, navigation and contextual panel. This is not a claim of an exhaustive native visual or functional pass for those screens. Keyboard-open search layouts, deeply nested sheets, long translations, RTL, desktop resizing during drag, and platform integrations still require live checks. Some text-only data panels use Rows and should receive targeted large-text fixtures when their services can be mocked reliably.

## Verification scope

Responsive widget fixtures cover 320×568, 390×844, 844×390, 768×1024, 1024×768, 1280×720, 1440×900 and 1920×1080, each at 100% and 200% text scaling. They exercise collection grids, See All, headers/actions, compact song rows, shelves, full player and equalizer. Android/iOS/Windows/macOS/Linux theme platforms are represented. Phone fixtures include simulated top/bottom system insets.

These run on the Windows Flutter test runner. They do not verify iOS builds, Android audio, real safe-area geometry, mouse/keyboard behavior across native operating systems, or actual provider content. `adb devices -l` returned no attached devices, so the repository-requested live app log inspection could not run.

Final regression run: **57 tests passed** across collection logic, responsive fixtures, existing cover/safe-area checks, track validation and dynamic playlist reconciliation. Static analysis covers the New Experience directory, the new collection service, the song-options integration and both new test files.

## Spotify comparison and remaining product gaps

Reference behavior: [Spotify Mixes](https://support.spotify.com/us/article/spotify-mixes/), [Spotify Radio](https://support.spotify.com/us/article/spotify-radio/), [personalized playlist schedules](https://support.spotify.com/us/article/find-playlists/).

| Priority | Feature/mode | Assessment / next work |
| --- | --- | --- |
| Delivered | Artist/year/decade/mood/genre browsing | New dynamic collection catalogue; artist mixes focus on the named artist |
| Delivered | Album sessions and song radio | Seeded from actual catalogue/history metadata and available via new destinations |
| High | Save an entire dynamic station to Library | Per-song playlist actions exist; a station-level save/follow operation and refresh policy are still needed |
| High | Recommendation feedback | Add dislike/hide/block artist controls applied consistently to mixes, radio and autoplay |
| High | Time/activity mixes | Add morning/evening daylist, focus, workout and sleep sessions with history-aware ranking; do not label generic search as personalized AI |
| High | Followed-artist new releases | Existing Release Radar skeleton uses generic searches; needs release-date validation, artist following and reliable addon metadata |
| Medium | Weekly discovery scheduling | Discover Weekly skeleton exists; true weekly history-aware novelty selection and schedule enforcement remain distinct work |
| Medium | Radio continuation | Existing queue autoplay handles continuation; explicit station-aware replenishment, diversity and exclusion history need integration |
| Medium | Collaborative taste blend | Listening rooms/social features already exist; multi-user taste blending is separate and needs consent/data design |
| Medium | Playlist organization | Folders, station follows, smart library filters and pinned collections |
| Existing | Sleep timer, shuffle/repeat, queue editing, lyrics, equalizer, offline downloads | Already implemented; should not be advertised as newly added or missing |
| Existing but parity needs review | Driving mode, crossfade, casting/social destinations | Legacy implementations exist; verify entry points and parity in the new UI on native hardware |

## Artwork source decision

1. Prefer album/artist art returned by the installed music addon. It comes with the resolved entity and avoids title-only image mismatches. Existing artwork widgets supply caching and failure handling.
2. For metadata enrichment, [MusicBrainz Cover Art Archive](https://musicbrainz.org/doc/Cover_Art_Archive/API) supports release and release-group IDs and thumbnail variants. Use a verified release identifier, approved front art and cached lookup results. It is an appropriate optional addon/enrichment capability; it was not wired as a hardcoded provider here because this collection path has no verified MusicBrainz release IDs.
3. Use procedural collection covers and existing deterministic artwork fallbacks when no valid artwork is available. New collections derive their palette from a stable title checksum; they do not depend on arbitrary stock-image searches or brittle hand-written CDN paths.

Album artwork remains copyrighted. The archive is not a blanket commercial image license; see [MusicBrainz cover-art policy](https://musicbrainz.org/doc/Cover_Art). Artist portraits, editorial photography and marketing artwork require their own provenance and rights checks.

## Downstream synchronization

After these upstream changes have been published, run `git pull upstream master` inside the downstream `IT-Feels` directory. No downstream files were modified.
