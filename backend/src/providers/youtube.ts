import { NormalizedTrack } from './saavn';

export class YoutubeProvider {
  private static PIPED_INSTANCES = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.privacydev.net',
    'https://pipedapi.mha.fi',
  ];

  /**
   * Search YouTube for audio tracks via YoutubeExplode / InnerTube API logic
   */
  static async search(query: string, limit = 20): Promise<NormalizedTrack[]> {
    for (const instance of this.PIPED_INSTANCES) {
      try {
        const url = `${instance}/search?q=${encodeURIComponent(query)}&filter=music_songs`;
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) continue;

        const data = (await response.json()) as any;
        const items = data.items || [];

        return items.slice(0, limit).map((item: any) => {
          const videoId = item.url ? item.url.split('v=')[1] : '';
          return {
            id: `youtube:${videoId}`,
            provider: 'youtube',
            title: item.title || 'Unknown Title',
            artist: item.uploaderName || item.uploaderUrl?.replace('/', '') || 'YouTube Artist',
            album: 'YouTube Music',
            duration: item.duration || 0,
            coverArt: item.thumbnail || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
            hasLyrics: false,
            language: 'unknown',
            year: 2024,
            explicit: false,
          };
        });
      } catch (e) {
        // Try next Piped instance on failure
      }
    }

    // Direct InnerTube search fallback
    return await this.directInnerTubeSearch(query, limit);
  }

  /**
   * Direct InnerTube search fallback
   */
  private static async directInnerTubeSearch(query: string, limit = 20): Promise<NormalizedTrack[]> {
    try {
      const url = `https://www.youtube.com/youtubei/v1/search`;
      const body = {
        context: {
          client: {
            clientName: 'WEB_REMIX',
            clientVersion: '1.20240101.01.00',
            hl: 'en',
            gl: 'US',
          },
        },
        query: query,
        params: 'EgWKAQIYAWoKEAMQBBAJEAoQCQ%3D%3D', // Filter for songs
      };

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      if (!response.ok) return [];

      const data = (await response.json()) as any;
      const contents = data.contents?.twoColumnSearchResultsRenderer?.primaryContents?.sectionListRenderer?.contents || [];

      const tracks: NormalizedTrack[] = [];
      for (const section of contents) {
        const items = section.itemSectionRenderer?.contents || [];
        for (const item of items) {
          const renderer = item.musicResponsiveListItemRenderer || item.videoRenderer;
          if (!renderer) continue;

          const videoId = renderer.videoId || renderer.navigationEndpoint?.watchEndpoint?.videoId || '';
          if (!videoId) continue;

          const title = renderer.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || renderer.title?.runs?.[0]?.text || 'Unknown Title';
          const artist = renderer.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || renderer.ownerText?.runs?.[0]?.text || 'YouTube Artist';
          const thumbnail = renderer.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.slice(-1)[0]?.url || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;

          tracks.push({
            id: `youtube:${videoId}`,
            provider: 'youtube',
            title,
            artist,
            album: 'YouTube Music',
            duration: 0,
            coverArt: thumbnail,
            hasLyrics: false,
            language: 'unknown',
            year: 2024,
            explicit: false,
          });

          if (tracks.length >= limit) break;
        }
      }
      return tracks;
    } catch (e) {
      console.error('InnerTube search failed:', e);
      return [];
    }
  }

  /**
   * Resolves direct streamable Opus / AAC audio URL via YoutubeExplode / Piped engine
   */
  static async getAudioStream(videoId: string): Promise<string | null> {
    const cleanId = videoId.includes(':') ? videoId.split(':')[1] : videoId;

    for (const instance of this.PIPED_INSTANCES) {
      try {
        const url = `${instance}/streams/${cleanId}`;
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) continue;

        const data = (await response.json()) as any;
        const audioStreams = data.audioStreams || [];

        // Select highest quality audio stream (webm/opus or m4a/aac)
        if (audioStreams.length > 0) {
          audioStreams.sort((a: any, b: any) => (b.bitrate || 0) - (a.bitrate || 0));
          return audioStreams[0].url || null;
        }
      } catch (e) {
        // Try next instance on failure
      }
    }

    return null;
  }
}
