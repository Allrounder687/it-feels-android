# Music Data Source Registry & Federation Matrix
**IT Feels Music — Enterprise Product Evolution 2026**
*Document Version: 1.0.0 | Status: Active Production Architecture*

---

## 1. Executive Summary

IT Feels Music's Enterprise Intelligence ecosystem shifts from a single-source catalogue dependency to an enterprise-grade federated metadata architecture. The system orchestrates a hybrid fabric of primary catalogue providers, open metadata repositories, encyclopedic ontologies, community-curated genre networks, high-resolution artwork archives, and synchronized lyrics providers.

Each provider operates through dedicated adapter interfaces governed by strict rate-limiting, circuit breakers, tiered caching, and legal provenance tracking. Playback audio availability remains 100% independent from external metadata services, guaranteeing zero disruption to playback when third-party metadata APIs experience throttling or downtime.

---

## 2. Integrated Provider Matrix

| Provider Name | Role | Primary Endpoint | Auth Method | Rate Limit | Cache TTL | License / Attribution |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **JioSaavn** | Primary Catalog & Playback Stream URLs | `https://www.jiosaavn.com/api.php` (via Cloudflare Proxy) | None (Public API) | Dynamic / Edge throttled | 24 Hours | Commercial Streaming Partner terms |
| **Addon System** | Dynamic Stream Resolver (YouTube/SoundCloud/etc.) | Local Sandboxed Addon Engine | Addon-defined | Addon-defined | 1 Hour | User-installed Addon compliance |
| **Local Media Scanner** | Offline Audio Files & Companion Metadata | File System (`Music/`, `downloaded_music/`) | OS Permissions | None | Indefinite (File watcher sync) | User-owned files |
| **MusicBrainz** | Authoritative Recording, Release & Contributor Metadata | `https://musicbrainz.org/ws/2/` | User-Agent Header | 1 request/second | 7 Days (L1/L2) | CC0 1.0 / Open Data Commons Open Database License (ODbL) |
| **Wikidata** | Encyclopedic Biographies, Country of Origin, Native Script | `https://www.wikidata.org/w/api.php` | User-Agent Header | Respectful (10 req/s max) | 14 Days | CC0 1.0 Universal Dedicated Domain |
| **Last.fm** | Community Tags, Similar Artists, Bio Extracts | `https://ws.audioscrobbler.com/2.0/` | API Key (`api_key` query param) | 5 requests/second | 48 Hours | Last.fm API Terms of Use (Non-commercial, attributed) |
| **ListenBrainz** | Open Listening Analytics & Community Scrobbles | `https://api.listenbrainz.org/1/` | User-Agent / Optional Token | 2 requests/second | 24 Hours | CC0 1.0 Universal / Open Source |
| **Cover Art Archive** | High-Res Front Covers & Booklet Imagery | `https://coverartarchive.org/release/` | None (Direct CDN redirect) | No hard cap (Internet Archive CDN) | 30 Days | CC0 / Public Domain / Fair Use Editorial |
| **Fanart.tv** | Supplementary Artist Banners & ClearArt | `https://webservice.fanart.tv/v3/` | Client Key | 2 requests/second | 14 Days | Non-commercial Community Attribution |
| **LRCLIB** | Synchronized (.lrc) and Plain Text Lyrics | `https://lrclib.net/api/get` | User-Agent Header | 2 requests/second | 30 Days (Disk LRC) | Community-driven Open Lyrics Service |
| **Edge Lyrics Proxy** | Fallback Synced Lyrics & Transliteration | `https://it-feels-proxy.cleverfox687.workers.dev/api/v1/lyrics` | Cloudflare Edge HMAC | Edge-cached (1000 req/min) | 30 Days | IT Feels Cloudflare Edge Infrastructure |

---

## 3. Provider Deep Dives

### 3.1 JioSaavn (Primary Catalogue & Playback)
- **Role:** Master catalog index for song discovery, top hits, albums, playlists, high-bitrate streaming audio URLs (320kbps MP4/AAC), and 500x500 album art.
- **Protocol:** HTTPS REST (JSON format).
- **Transport Resilience:** Routed through IT Feels Cloudflare Edge Proxy (`https://it-feels-proxy.cleverfox687.workers.dev/api/v1/image-proxy?url=...`) with direct HTTPS fallback. This completely eliminates Akamai TLS resets on desktop/Windows clients.
- **Failover Behavior:** If JioSaavn fails or is unreachable, the player seamlessly falls back to installed dynamic Addons or local offline media.

### 3.2 MusicBrainz (Recording & Artist Metadata Authority)
- **Role:** Provides canonical recording credits (composers, lyricists, producers, arrangers, recording engineers), release group dates, label information, and International Standard Recording Codes (ISRC).
- **Endpoint Structure:**
  - Recording Search: `/ws/2/recording?query=recording:"..." AND artist:"..."&fmt=json`
  - Release Group Lookup: `/ws/2/release-group?artist=...&type=album|single&fmt=json`
  - Artist Relationship Lookup: `/ws/2/artist/...&inc=artist-rels+url-rels&fmt=json`
- **Rate Limit Compliance:** Governed by `TokenBucketRateLimiter` configured for 1.0 token/second with burst 1.0. All requests transmit a descriptive User-Agent: `ITFeelsMusic/3.8.0 ( https://github.com/it-feels/it-feels-android )`.
- **Licensing & Attribution:** Core database is CC0 1.0 Universal. Attributed as "Metadata powered by MusicBrainz".

### 3.3 Wikidata (Biographical & Ontological Enrichment)
- **Role:** Resolves artist native-script names (e.g. Arijit Singh in Devanagari `अरिजीत सिंह`, Punjabi `ਅਰਿਜੀਤ ਸਿੰਘ`), country of citizenship, active years, birth/formation places, and official homepage links.
- **Endpoint Structure:**
  - SPARQL Entity Resolution / Action API: `action=wbsearchentities&search=...&type=item&language=en&format=json`
  - Entity Claims: `action=wbgetentities&ids=...&props=claims|labels&languages=en|hi|pa|ta|te`
- **Rate Limit Compliance:** Governed by 3 requests/second ceiling. Requests pass `Accept-Language` headers and identifiable User-Agent.
- **Licensing & Attribution:** 100% CC0 1.0 Universal public domain.

### 3.4 Last.fm (Community Discovery & Folksonomy)
- **Role:** Extracts top user tags for genre mapping (e.g., "acoustic bollywood", "sufi rock"), similar artists with match weight scores, and short editorial biography snippets.
- **Endpoint Structure:**
  - `method=artist.getInfo&artist=...&api_key=...&format=json`
  - `method=artist.getSimilar&artist=...&api_key=...&format=json`
  - `method=track.getSimilar&artist=...&track=...&api_key=...&format=json`
- **Rate Limit Compliance:** 5.0 requests/second token bucket.
- **Licensing & Attribution:** Used under Last.fm API Non-Commercial terms. Cached responses display Last.fm user scrobble attribution where applicable.

### 3.5 Cover Art Archive (High-Fidelity Visuals)
- **Role:** High-resolution front album art, back covers, and liner notes sourced from the Internet Archive.
- **Endpoint Structure:**
  - Release Front: `https://coverartarchive.org/release/{mbid}/front-500`
  - Release Group Front: `https://coverartarchive.org/release-group/{mbid}/front-1200`
- **Resolution Strategy:** Replaces lower-resolution or stretched catalog covers with verified 500px and 1200px lossless artwork when MBID matches with $\ge 0.85$ confidence.

### 3.6 LRCLIB (Synchronized Lyrics)
- **Role:** Precise word-by-word and line-by-line synchronized timestamped lyrics (`.lrc`) and plain text fallback.
- **Endpoint Structure:**
  - `https://lrclib.net/api/get?track_name=...&artist_name=...&album_name=...&duration=...`
- **Storage Policy:** Downloaded `.lrc` files are permanently stored in the local music directory alongside offline tracks and cached in Isar DB with 30-day freshness for streaming tracks.

---

## 4. Multi-Source Priority & Fallback Chains

### 4.1 Track Metadata Priority
```text
Title & Main Artist:   1. JioSaavn/Primary   -> 2. MusicBrainz        -> 3. Local ID3 Tag
Composers & Lyricists: 1. MusicBrainz        -> 2. JioSaavn Credits   -> 3. Wikidata
ISRC & Barcode:        1. MusicBrainz        -> 2. JioSaavn Catalog
Release Date:          1. MusicBrainz (RG)   -> 2. JioSaavn Catalog   -> 3. Wikidata
Artwork URL:           1. Cover Art Archive  -> 2. JioSaavn (500x500) -> 3. Embedded ID3
Lyrics:                1. Local .lrc file    -> 2. LRCLIB             -> 3. Cloudflare Edge Proxy
```

### 4.2 Artist Intelligence Priority
```text
Portrait & Backdrop:   1. Fanart.tv / MB     -> 2. JioSaavn High-Res  -> 3. Last.fm Mega
Native / Regional Name:1. Wikidata           -> 2. MusicBrainz Aliases
Country & Birthplace:  1. Wikidata           -> 2. MusicBrainz Area
Genres & Tags:         1. Last.fm Folksonomy -> 2. JioSaavn Subtype   -> 3. MusicBrainz Tags
Collaborators:         1. MusicBrainz Rels   -> 2. Listening Co-occurrence
Similar Artists:       1. Last.fm (Weighted) -> 2. JioSaavn Radio     -> 3. Vector Embeddings
```

---

## 5. Security, Proxying & Rate Limiting Enforcement

1. **Server-Side Request Forgery (SSRF) Protection:**
   The `EnterpriseApiOrchestrator` runs all target URIs through `_validateUrlSecurity()`. Requests attempting to hit `localhost`, `127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, `169.254.169.254` (cloud metadata), or non-HTTP(S) schemes are blocked immediately.
2. **Exponential Backoff with Full Jitter:**
   Transient errors (HTTP 429, 502, 503, 504, socket timeouts) undergo exponential backoff with randomized jitter up to 3 retries:
   $$t_{\text{wait}} = \min(t_{\text{max}}, t_{\text{base}} \times 2^{\text{attempt}}) \times \text{uniform}(0.75, 1.25)$$
3. **Edge Proxy Masking:**
   Requests vulnerable to Akamai or regional CDN blocking route via Cloudflare Workers Edge with automatic keep-alive connection pooling.
