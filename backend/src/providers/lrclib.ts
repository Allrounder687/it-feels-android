export interface LyricsResult {
  trackName: string;
  artistName: string;
  albumName?: string;
  plainLyrics?: string;
  syncedLyrics?: string;
  source: string;
}

export class LrcLibProvider {
  private static BASE_URL = 'https://lrclib.net/api';

  static async getLyrics(trackName: string, artistName: string, albumName?: string, duration?: number): Promise<LyricsResult | null> {
    try {
      const params = new URLSearchParams({
        track_name: trackName,
        artist_name: artistName,
      });

      if (albumName) params.append('album_name', albumName);
      if (duration && duration > 0) params.append('duration', duration.toString());

      const response = await fetch(`${this.BASE_URL}/get?${params.toString()}`);
      if (!response.ok) {
        // Fallback to search if exact match fail
        return await this.searchLyrics(trackName, artistName);
      }

      const data = (await response.json()) as any;
      return {
        trackName: data.trackName || trackName,
        artistName: data.artistName || artistName,
        albumName: data.albumName,
        plainLyrics: data.plainLyrics || undefined,
        syncedLyrics: data.syncedLyrics || undefined,
        source: 'lrclib',
      };
    } catch (e) {
      console.error('Failed to fetch lyrics from LrcLib:', e);
      return null;
    }
  }

  private static async searchLyrics(trackName: string, artistName: string): Promise<LyricsResult | null> {
    try {
      const query = encodeURIComponent(`${trackName} ${artistName}`);
      const response = await fetch(`${this.BASE_URL}/search?q=${query}`);
      if (!response.ok) return null;

      const results = (await response.json()) as any[];
      if (!results || results.length === 0) return null;

      const bestMatch = results[0];
      return {
        trackName: bestMatch.trackName || trackName,
        artistName: bestMatch.artistName || artistName,
        albumName: bestMatch.albumName,
        plainLyrics: bestMatch.plainLyrics || undefined,
        syncedLyrics: bestMatch.syncedLyrics || undefined,
        source: 'lrclib',
      };
    } catch (e) {
      return null;
    }
  }
}
