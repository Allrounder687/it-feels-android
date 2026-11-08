# Advanced Multi-Vector Discovery & Recommendation Engine Design
**IT Feels Music — Enterprise Product Evolution 2026**
*Document Version: 1.0.0 | Status: Production Specification & Algorithm Contract*

---

## 1. Engine Philosophy & Vision

IT Feels Music moves beyond naive "similar tracks" API queries to an authentic, multi-signal **Discovery Pipeline** (`RecommendationPipeline`). Recommendations are generated through a transparent, mathematical scoring engine that respects user autonomy, protects diversity, adapts to novelty preferences, and provides source-grounded explanations for every suggestion.

The engine operates on a local-first principle: user affinity vectors, play counts, skips, and time-of-day preferences reside exclusively on the device, ensuring personalized discovery without privacy compromise.

```text
+-----------------------------------------------------------------------------------+
|                            Candidate Generation Pool                              |
|   [ User Favorites ]   [ High-Affinity Artists ]   [ Collaborators ]  [ Catalogs ]|
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                        11-Stage Recommendation Pipeline                           |
|                                                                                   |
|  1. Exclusion Filtering     (Permanently hidden artists & tracks removed)         |
|  2. Snooze Filter           (Temporarily suppressed tracks skipped for 24h)       |
|  3. Deduplication           (Acoustic normalization & canonical ID matching)      |
|  4. Recency Suppression     (Avoid tracks played in last 4 hours / 15 songs)      |
|  5. User Taste Affinity     (Calculates artist & genre alignment scores)          |
|  6. Multi-Vector Scoring    (Computes Score(T) across artist, genre, mood, etc.)  |
|  7. Novelty Modulation      (Applies user-configured Novelty Tolerance factor)    |
|  8. Artist Diversity Capping(Enforces maximum 2 tracks per artist per shelf)      |
|  9. Category Selection      (Partitions candidates into 15 distinct archetypes)   |
| 10. Explanation Synthesis   (Generates grounded rationale for each suggestion)    |
| 11. Feed Formatting         (Emits immutable RankedRecommendation payload)        |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
                         New Experience UI / Audio Player
```

---

## 2. Mathematical Multi-Vector Scoring Formula

Every candidate track $T$ is evaluated against the user's multi-dimensional taste profile using the following objective function:

$$\text{Score}(T) = w_a A_{\text{artist}}(T) + w_g A_{\text{genre}}(T) + w_m M_{\text{mood}}(T) + w_r R_{\text{recency}}(T) + w_n N_{\text{novelty}}(T) - P_{\text{repetition}}(T)$$

### Factor Breakdown:
1. **Artist Affinity ($A_{\text{artist}}$):**
   Blended short-term ($t_{1/2} = 21\text{d}$) and long-term ($t_{1/2} = 180\text{d}$) affinity derived from user listening events:
   $$A_{\text{artist}} = 0.6 \cdot A_{\text{short}} + 0.4 \cdot A_{\text{long}}$$
2. **Genre Affinity ($A_{\text{genre}}$):**
   Normalized dot-product of track genre tags against the user's top genre affinity distribution.
3. **Mood & Context Alignment ($M_{\text{mood}}$):**
   Temporal alignment based on time of day (Morning: Acoustic/Gentle, Afternoon: Upbeat/Pop, Evening: Melodic/Romantic, Night: Lo-fi/Classical/Atmospheric).
4. **Catalog Recency ($R_{\text{recency}}$):**
   Bonus awarded to newly released singles or albums from artists in the user's listening sphere.
5. **Novelty Modulation ($N_{\text{novelty}}$):**
   Scaled by the user's interactive novelty slider ($\nu \in [0.0, 1.0]$):
   $$N_{\text{novelty}}(T) = \nu \cdot (1.0 - \text{Familiarity}(T))$$
6. **Repetition Penalty ($P_{\text{repetition}}$):**
   Penalizes tracks recently played or skipped:
   $$P_{\text{repetition}}(T) = \begin{cases} 
   10.0 & \text{if played within last 2 hours} \\
   3.0 & \text{if played within last 12 hours} \\
   5.0 & \text{if skipped early (< 30s) during last 3 impressions} \\
   0.0 & \text{otherwise}
   \end{cases}$$

---

## 3. The 15 Recommendation Categories

The discovery engine organizes suggestions into 15 authentic, distinct categories:

| Index | Category Enum | Purpose & Algorithmic Strategy |
| :--- | :--- | :--- |
| **1** | `discoverWeekly` | Weekly refreshed blend of familiar high-affinity genres with 35% novel artist introductions. |
| **2** | `listeningHistory` | Tracks that naturally flow from the user's last 5 played songs and current listening session. |
| **3** | `similarSongs` | Acoustically and harmonically aligned songs matching the current active seed track. |
| **4** | `similarArtists` | Artists sharing collaborative networks, record labels, and stylistic folksonomy tags. |
| **5** | `forgottenFavorites` | Highly-rated or heavily-played tracks that have not been played by the user in $\ge 45$ days. |
| **6** | `deepCatalogue` | Non-single B-sides, deep album cuts, and hidden gems from the user's favorite artists. |
| **7** | `regionalDiscovery` | Authentic regional and folk traditions (Punjabi, Sufi, Carnatic, Bengali, Tamil Indie). |
| **8** | `languageDiscovery` | Curated tracks expanding into languages adjacent to user favorites (e.g. Hindi $\rightarrow$ Urdu/Punjabi). |
| **9** | `moodDiscovery` | Contextual playlists matched to current time-of-day circadian rhythm and energy requirements. |
| **10** | `genreDiscovery` | Dedicated deep dives exploring niche subgenres with high user affinity growth. |
| **11** | `collaboratorDiscovery` | Uncovering songs produced, composed, or arranged by the user's favorite background musicians. |
| **12** | `undergroundArtists` | Independent and emerging artists with low global play counts but high acoustic quality. |
| **13** | `followedArtists` | Fresh releases, singles, and EPs from artists explicitly followed or favorited by the user. |
| **14** | `rediscoverOld` | Nostalgic hits from earlier decades (e.g. 90s/2000s Bollywood, classic Ghazals) matching taste. |
| **15** | `unexpectedDiscovery` | Controlled serendipity: highly praised tracks outside the user's top genres, weighted by novelty tolerance. |

---

## 4. Grounded Recommendation Explanations

To demystify recommendations and build user trust, every suggestion is paired with an explainable rationale:
- *"Because you frequently listen to Arijit Singh"* (Artist affinity connection)
- *"Acoustically similar to 'Tum Hi Ho' with shared composer Pritam"* (Collaborator / acoustic connection)
- *"You haven't played this favorite in 2 months"* (Forgotten favorite trigger)
- *"Matches your relaxed late-night listening rhythm"* (Circadian context)
- *"Top recommendation from your favorite genre: Sufi Rock"* (Genre affinity trigger)

---

## 5. Explicit User Feedback Controls

Users maintain total control over recommendations through interactive feedback actions:

```dart
enum RecommendationFeedbackType {
  moreLikeThis,          // Boosts artist & genre affinity (+2.0)
  lessLikeThis,          // Decreases artist & genre affinity (-1.5)
  hideTrack,             // Permanently excludes track from future suggestions
  hideArtist,            // Permanently excludes all tracks by this artist
  snooze,                // Suppresses track for 24 hours
  notInterested,         // Suppresses this specific recommendation category for 7 days
  refreshRecommendations,// Purges session cache and rotates candidate seeds
}
```

### Persistence & Reactive Application
- Hidden entities are stored in `SharedPreferences` under `hidden_artists` and `hidden_songs`.
- The `RecommendationPipeline` injects these blacklists as the very first stage of evaluation, guaranteeing that hidden items never surface in home feeds, charts, or endless discovery queues.
