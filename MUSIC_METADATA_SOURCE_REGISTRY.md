# Music Metadata Source Registry & Attribution Specification
**IT Feels Music — Project Obsidian 2026**
*Document Version: 1.0.0 | Status: Production Source Registry*

---

## 1. Metadata Federation Philosophy

Project Obsidian enforces a strict **Zero-Hallucination, Multi-Source Federation Policy**:
- **Truth Anchors:** Song metadata, artist biographies, and release credits must be verified by authoritative public repositories or primary stream providers.
- **Provider Independence:** The playback audio pipeline operates 100% independently from external metadata sources. Playback never halts if an external metadata API is unreachable or rate-limited.
- **Attribution & Terms:** Every source is utilized within its legal terms of service, respecting non-commercial clauses, CC0 dedications, and required citations.

---

## 2. Integrated Metadata Sources Matrix

| Source / Provider | Data Extracted | Base Endpoint | Rate Limit | Cache TTL | License & Attribution |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **JioSaavn** | Song title, primary artist, album name, duration, stream URLs, standard cover art | `https://www.jiosaavn.com/api.php` | Dynamic (Via Edge Proxy) | 24 Hours | Proprietary streaming partner terms |
| **MusicBrainz** | Structured recording credits, composers, lyricists, producers, ISRC, release groups | `https://musicbrainz.org/ws/2/` | Strict 1.0 req/sec | 7 Days | CC0 1.0 Universal / ODbL ("Metadata powered by MusicBrainz") |
| **Wikidata** | Native script artist names, country of origin, active years, birth/formation dates | `https://www.wikidata.org/w/api.php` | 3.0 req/sec | 14 Days | CC0 1.0 Universal Public Domain |
| **Cover Art Archive**| High-resolution front album covers (500px & 1200px lossless) | `https://coverartarchive.org/release/` | 5.0 req/sec | 30 Days | CC0 / Public Domain / Fair Use (Internet Archive & MusicBrainz) |
| **Last.fm** | Community folksonomy genre tags, similar artists, concise biography abstracts | `https://ws.audioscrobbler.com/2.0/` | 5.0 req/sec | 48 Hours | Last.fm Non-Commercial API Terms ("Powered by Last.fm") |
| **ListenBrainz** | Open listening statistics and community listening patterns | `https://api.listenbrainz.org/1/` | 2.0 req/sec | 24 Hours | CC0 1.0 Universal (MetaBrainz Foundation) |
| **LRCLIB** | Synchronized line-by-line (.lrc) timestamped lyrics and plain text | `https://lrclib.net/api/get` | 2.0 req/sec | 30 Days (Disk LRC)| Open community-contributed database |
| **Local File Scanner**| ID3v2 / Vorbis metadata, embedded album art, local duration | Filesystem | Unrestricted | Indefinite | User-owned media files |

---

## 3. Provenance & Priority Resolution Hierarchy

When reconciling disparate metadata for a musical work:

```text
Field: Track Title & Artist
1. JioSaavn Primary Catalog (Highest verified playback match)
2. MusicBrainz Recording Entry (Authoritative canonical spelling)
3. Local File Tag (Offline fallback)

Field: Recording Personnel (Composer, Lyricist, Producer)
1. MusicBrainz ws/2 Recording Work Relationships
2. JioSaavn Editorial Credits
3. Wikidata Ontological Claims

Field: Album Cover Art
1. Local companion 'cover.jpg' (If offline track exists)
2. Cover Art Archive 1200px / 500px front art (If MBID matched >= 0.85)
3. JioSaavn 500x500 high-res artwork
4. Embedded ID3 APIC image frame

Field: Lyrics & Time Sync
1. Local companion 'lyrics.lrc' file in music folder
2. LRCLIB synchronized LRC response
3. Cloudflare Edge Synced Lyrics service
```

---

## 4. Rate Limiting & Resilience Architecture

All outbound metadata queries are mediated by the `EnterpriseApiOrchestrator`:
- **Token Bucket Enforcement:** MusicBrainz is restricted to 1 token/second with zero burst overshoot, transmitting descriptive User-Agent headers (`ITFeelsMusic/3.8.0`).
- **Circuit Breaker Protection:** If a provider encounters 5 consecutive failures, its circuit trips to `OPEN` for 30 seconds, fail-fasting subsequent requests to prevent UI freezes.
- **SSRF Sanitization:** All URLs are verified against private RFC 1918 and loopback subnets before network transmission.
