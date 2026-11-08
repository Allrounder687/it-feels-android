# Unified Search Engine Architecture & Relevance Ranking
**IT Feels Music — Project Obsidian 2026**
*Document Version: 1.0.0 | Status: Production Search Engine Specification*

---

## 1. Search Philosophy & Objectives

In a world-class music application, search must feel instantaneous, intelligent, and reliable under any network condition. Search is not merely an API proxy—it is a multi-tier query routing engine that bridges local offline media with global catalogue discovery.

```text
+-----------------------------------------------------------------------------------+
|                         NewSearchScreen (User Input)                              |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                      SearchNotifier (Debounce 300ms)                              |
|                                                                                   |
|  +---------------------------+       +------------------------------------------+ |
|  | Persistent Search History |       | In-Flight Token Cancellation Watchdog    | |
|  +---------------------------+       +------------------------------------------+ |
+-----------------------------------------------------------------------------------+
                                         |
                    +--------------------+--------------------+
                    |                                         |
                    v                                         v
   +---------------------------------+       +---------------------------------+
   |      Local Library Matcher      |       |      Global Catalog Resolver    |
   |  - Downloaded Songs Search      |       |  - JioSaavn Primary Endpoint    |
   |  - Liked Songs Search           |       |  - Cloudflare Edge Proxy        |
   |  - Custom Playlists Search      |       |  - Track Validation Engine      |
   +---------------------------------+       +---------------------------------+
                    |                                         |
                    +--------------------+--------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                         Composite Result Reranker                                 |
|                                                                                   |
|  1. Local Library Matches ("In Your Library") [Offline Ready]                     |
|  2. Top Artist Match (Hero Avatar + Quick Profile Action)                         |
|  3. Relevance-Scored Tracklist (Clean cuts prioritized over remixes)              |
|  4. Album & Playlist Carousels                                                    |
+-----------------------------------------------------------------------------------+
```

---

## 2. Multi-Source Query Routing & Offline Resilience

### 2.1 Dual-Track Local + Remote Execution
When a user types a query (e.g. `"Kesariya"`):
1. **Local Pipeline (< 5ms):** Instantly scans the local device storage (`StorageService.loadDownloads()`, `AudioPlayerState.favoriteSongs`, and `customPlaylistProvider`). Any matching tracks surface immediately in an **"In Your Library"** shelf tagged with the cyan offline-ready badge.
2. **Remote Pipeline (~150ms):** Concurrently dispatches an authenticated query through the edge proxy to fetch global tracks, artists, and albums.
3. **Offline Fallback Guarantee:** If the device has no internet connectivity or encounters a network timeout, the online error is gracefully absorbed and the user is presented with their matching local library tracks without encountering an empty screen or error dialog.

---

## 3. Mathematical Relevance Scoring

Remote catalogue search results are reranked via `_calculateSongRelevance()` to prioritize authentic original album tracks over low-quality covers or fan remixes:

$$\text{Score}(S) = S_{\text{title}} + S_{\text{artist}} + S_{\text{album}} + S_{\text{tokens}} - P_{\text{modifier}}$$

### 3.1 Scoring Weights
- **Exact Title Equality:** $+150$ points (e.g. query `"Channa Mereya"` exactly matches title).
- **Clean Title Equality (Parentheticals stripped):** $+150$ points (e.g. `"Channa Mereya (From Ae Dil Hai Mushkil)"` matches `"Channa Mereya"`).
- **Prefix Title Match:** $+90$ points.
- **Substring Title Match:** $+50$ points.
- **Exact Artist Equality:** $+110$ points.
- **Artist Prefix Match:** $+70$ points.
- **Token Overlap:** Up to $+35$ points proportional to token intersection ratio.

### 3.2 Unwanted Modifier Penalty ($P_{\text{modifier}}$)
Unless the user explicitly typed keywords such as `"remix"`, `"lofi"`, or `"cover"`:
$$P_{\text{modifier}} = \begin{cases}
90 & \text{if title contains "remix", "mix", "lofi", or "cover"} \\
0 & \text{otherwise}
\end{cases}$$
This prevents algorithmic pollution where obscure remixes rank higher than the definitive studio master.

---

## 4. Debouncing & Keystroke Optimization

- **300ms Debounce Window:** Consecutive keystrokes cancel prior timers, preventing rapid typing from initiating 10 redundant network requests.
- **Persistent Search History:** Stores the last 10 successful search queries in `SharedPreferences`. Displayed as interactive chips on empty search states with one-tap execution and individual or bulk clearing.
- **Filter Segregation:** Interactive filter capsules (`All`, `Songs`, `Artists`, `Albums`, `Playlists`) filter the results in-memory without re-fetching.
