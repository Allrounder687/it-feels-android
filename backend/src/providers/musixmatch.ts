import { LyricsResult } from './lrclib';

export class MusixmatchProvider {
  private static USER_TOKEN = '20052100000000000000000000000000';
  private static BASE_URL = 'https://apic-desktop.musixmatch.com/ws/1.1';

  /**
   * Fetch synced or plain lyrics from Musixmatch API
   */
  static async getLyrics(trackName: string, artistName: string, albumName?: string): Promise<LyricsResult | null> {
    try {
      const params = new URLSearchParams({
        format: 'json',
        q_track: trackName,
        q_artist: artistName,
        user_language: 'en',
        usertoken: this.USER_TOKEN,
        app_id: 'web-desktop-app-v1.0',
      });

      if (albumName) params.append('q_album', albumName);

      const response = await fetch(`${this.BASE_URL}/macro.subtitles.get?${params.toString()}`, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Cookie': 'awselb=123',
        },
      });

      if (!response.ok) return null;

      const data = (await response.json()) as any;
      const macroCalls = data?.message?.body?.macro_calls;

      if (!macroCalls) return null;

      // Extract synced LRC subtitles
      const subtitleObj = macroCalls['track.subtitles.get']?.message?.body?.subtitle_list?.[0]?.subtitle;
      if (subtitleObj && subtitleObj.subtitle_body) {
        return {
          trackName,
          artistName,
          albumName,
          syncedLyrics: subtitleObj.subtitle_body,
          source: 'musixmatch',
        };
      }

      // Extract plain text lyrics if synced unavailable
      const lyricsObj = macroCalls['track.lyrics.get']?.message?.body?.lyrics;
      if (lyricsObj && lyricsObj.lyrics_body) {
        return {
          trackName,
          artistName,
          albumName,
          plainLyrics: lyricsObj.lyrics_body,
          source: 'musixmatch',
        };
      }
    } catch (e) {
      console.error('Musixmatch lyrics fetch error:', e);
    }
    return null;
  }
}
