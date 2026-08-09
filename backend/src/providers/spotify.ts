import { NormalizedTrack, SaavnProvider } from './saavn';
import { YoutubeProvider } from './youtube';

export class SpotifyProvider {
  private static SPOTIFY_EMBED_URL = 'https://open.spotify.com/oembed';

  /**
   * Search Spotify track catalog via open web search
   */
  static async search(query: string, limit = 20): Promise<NormalizedTrack[]> {
    try {
      // Use open search endpoint for Spotify catalog
      const url = `https://spclient.wg.spotify.com/search-api/v2/search?q=${encodeURIComponent(query)}&type=tracks&limit=${limit}`;
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      });

      if (response.ok) {
        const data = (await response.json()) as any;
        const tracks = data?.tracks?.items || [];

        return tracks.map((item: any) => {
          const track = item.track || item;
          const artists = track.artists?.map((a: any) => a.name).join(', ') || 'Spotify Artist';
          const album = track.album?.name || '';
          const coverArt = track.album?.images?.[0]?.url || '';
          const duration = Math.floor((track.duration_ms || 0) / 1000);

          return {
            id: `spotify:${track.id || track.uri?.split(':').pop()}`,
            provider: 'spotify' as const,
            title: track.name || 'Unknown Title',
            artist: artists,
            album,
            duration,
            coverArt,
            hasLyrics: false,
            language: 'unknown',
            year: 2024,
            explicit: track.explicit === true,
          };
        });
      }
    } catch (e) {
      console.error('Spotify API search failed:', e);
    }

    // Fallback: Use Saavn/YouTube with Spotify metadata tags
    return await this.searchFallback(query, limit);
  }

  private static async searchFallback(query: string, limit = 20): Promise<NormalizedTrack[]> {
    const saavnResults = await SaavnProvider.search(query, 1, limit);
    return saavnResults.map((t) => ({
      ...t,
      id: t.id.replace('saavn:', 'spotify:'),
      provider: 'spotify' as const,
    }));
  }

  /**
   * Provider Chaining (extraDeps): Resolves stream for Spotify tracks via Saavn / YouTube
   */
  static async getAudioStream(trackTitle: string, artistName: string, ytDlpUrl?: string): Promise<string | null> {
    // 1. Primary Chain: Try Saavn 320kbps high-res matching
    try {
      const saavnSearch = await SaavnProvider.search(`${trackTitle} ${artistName}`, 1, 5);
      if (saavnSearch.length > 0) {
        // Strict Match Enforcement
        const topResult = saavnSearch[0];
        const matchTitle = topResult.title.toLowerCase();
        const targetTitle = trackTitle.toLowerCase();
        
        // Accept only if titles closely match (e.g. subset of each other) to prevent playing random songs
        if (matchTitle.includes(targetTitle) || targetTitle.includes(matchTitle)) {
           if (topResult.streamUrl) {
             return topResult.streamUrl;
           }
        }
      }
    } catch (e) {
      // Fall through to YouTube
    }

    // 2. Secondary Chain: Try YouTube / YoutubeExplode audio stream
    try {
      const ytSearch = await YoutubeProvider.search(`${trackTitle} ${artistName}`, 3);
      if (ytSearch.length > 0) {
        let streamUrl = await YoutubeProvider.getAudioStream(ytSearch[0].id);
        if (!streamUrl && ytDlpUrl) {
          try {
            const cleanId = ytSearch[0].id.includes(':') ? ytSearch[0].id.split(':')[1] : ytSearch[0].id;
            const res = await fetch(`${ytDlpUrl}/api/streams?videoId=${cleanId}`);
            if (res.ok) {
              const data = await res.json() as any;
              streamUrl = data.audioUrl || null;
            }
          } catch (e) {}
        }
        if (streamUrl) return streamUrl;
      }
    } catch (e) {
      // Stream failed
    }

    return null;
  }
}
