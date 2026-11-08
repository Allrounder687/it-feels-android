# IT Feels Music — Permanent Content Quality Standards
**Project Obsidian — Phase 5: Living Music Catalogue**  
*Document Version: 3.9.4 | Target: Clean/Addon Upstream (IT_Feels_Alternate)*

---

## 1. Architectural Mandates (Non-Negotiable)

Every content module, collection builder, dynamic mix, and catalogue screen in **IT Feels Music** must strictly obey these engineering standards:

1. **Genuine Catalogue Data Only:**
   - Zero hallucinated, synthetic, or AI-generated music recommendations.
   - All tracks, artists, and albums must originate from authentic metadata providers (JioSaavn, MusicBrainz, Last.fm, Cover Art Archive, Wikidata).
2. **Artwork Integrity Rule:**
   - Every single track, album, playlist, and daily mix must display valid, verified cover art.
   - Never display an empty black placeholder, a broken image icon, or a generic placeholder when legitimate artwork is resolvable.
   - Automatically generated collections must use deterministic composite quad-artwork generated from actual constituent tracks via `ArtworkRepairService`.
3. **Strict Global Deduplication:**
   - All collection feeds must pass through `CatalogueDeduplicationEngine`.
   - Identical recordings must be consolidated.
   - Legitimate variants (Live, Remix, Acoustic, Remastered, Instrumental, Karaoke, Deluxe, Lo-Fi) must **NEVER** be merged.
4. **Mood & Genre Discipline:**
   - Classifications must derive through `MoodGenreIntelligenceService`.
   - Never confuse emotional states (Moods: Happy, Melancholic, Romantic, Energetic) with musical styles/traditions (Genres: Pop, Rock, Hip-Hop, Classical, Folk, Regional).
5. **Cold-Start Persistence:**
   - Feeds, Daily Mixes, and dynamic playlists must persist to disk storage (`SharedPreferences` / `Isar`) and be instantly hydrated on cold restart.

---

## 2. Minimum Track Count Standards

| Collection Type | Minimum Track Count | Ideal Track Count | Deduplication Ceiling |
| :--- | :---: | :---: | :---: |
| **Daily Mix (Mixes 1-6)** | 15 tracks | 25 tracks | Max 0 identical duplicates |
| **Curated Playlist** | 12 tracks | 25-50 tracks | Max 0 identical duplicates |
| **Artist Top Tracks** | 8 tracks | 20 tracks | Max 0 identical duplicates |
| **Album Tracklist** | Full release (all tracks) | Full release | Preserve original disc order |
| **Chart Aggregation Feed** | 25 tracks | 50-100 tracks | Max 0 identical duplicates |
| **Search Results (Per Category)**| 5 tracks | 25 tracks | Max 0 identical duplicates |

---

## 3. Content Health Scoring Equation

The central `ContentHealthService` evaluates every content shelf using the weighted health scoring formula:

$$\text{HealthScore} = \left( 0.30 \cdot \frac{N_{\text{valid}}}{N_{\text{total}}} \right) + \left( 0.40 \cdot \frac{N_{\text{playable}}}{N_{\text{total}}} \right) + \left( 0.30 \cdot \frac{N_{\text{validArtwork}}}{N_{\text{total}}} \right) - \min\left(0.40, \frac{N_{\text{duplicates}}}{N_{\text{total}}}\right)$$

### Health Thresholds
- **Healthy ($\ge 0.88$):** Production-ready, fully verified content.
- **Needs Enrichment ($0.70 \le \text{Score} < 0.88$):** Missing secondary metadata or artwork; background repair queued.
- **Incomplete ($N_{\text{total}} < \text{Minimum}$):** Insufficient tracks; discovery pipeline active.
- **Degraded ($0.40 \le \text{Score} < 0.70$):** Playback or artwork failures present.
- **Failed ($< 0.40$):** Broken stream sources or corruption detected.

---

## 4. Developer Quality Gate

No pull request, feature, or AI iteration may introduce a new content shelf without:
1. Registering the shelf in `ContentHealthService`.
2. Routing artwork resolution through `ArtworkRepairService`.
3. Routing track lists through `CatalogueDeduplicationEngine`.
4. Passing automated verification tests in `test/unit/catalogue/`.
