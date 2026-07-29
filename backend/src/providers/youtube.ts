import { NormalizedTrack } from './saavn';

export interface VideoStreamItem {
  quality: string; // '1080p' | '720p' | '480p' | '360p'
  url: string;
  mimeType: string;
  hasAudio: boolean;
}

export interface VideoItem {
  id: string;
  title: string;
  uploader: string;
  duration: number;
  thumbnail: string;
  views: string;
  uploadedAt: string;
}

export class YoutubeProvider {
  private static PIPED_INSTANCES = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.privacydev.net',
    'https://pipedapi.mha.fi',
    'https://pipedapi.drgns.space',
  ];

  private static INVIDIOUS_INSTANCES = [
    'https://inv.tux.pizza',
    'https://invidious.nerdvpn.de',
    'https://invidious.drgns.space',
  ];

  /**
   * Search YouTube for audio tracks via YoutubeExplode / InnerTube API logic
   */
  static async search(query: string, limit = 20): Promise<NormalizedTrack[]> {
    // Primary: Direct InnerTube search
    const innerTubeResults = await this.directInnerTubeSearch(query, limit);
    if (innerTubeResults.length > 0) return innerTubeResults;

    // Fallback: Piped API search
    for (const instance of this.PIPED_INSTANCES) {
      try {
        const url = `${instance}/search?q=${encodeURIComponent(query)}&filter=music_songs`;
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) continue;

        const data = (await response.json()) as any;
        const items = data.items || [];
        if (items.length === 0) continue;

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

    return [];
  }

  /**
   * Search YouTube specifically for Video Items
   */
  static async searchVideos(query: string, limit = 20): Promise<VideoItem[]> {
    for (const instance of this.PIPED_INSTANCES) {
      try {
        const url = `${instance}/search?q=${encodeURIComponent(query)}&filter=videos`;
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) continue;

        const data = (await response.json()) as any;
        const items = data.items || [];
        if (items.length === 0) continue;

        return items.slice(0, limit).map((item: any) => {
          const videoId = item.url ? item.url.split('v=')[1] : '';
          return {
            id: `youtube:${videoId}`,
            title: item.title || 'Unknown Title',
            uploader: item.uploaderName || 'YouTube Creator',
            duration: item.duration || 0,
            thumbnail: item.thumbnail || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
            views: item.views ? `${(item.views / 1000).toFixed(1)}k views` : 'Popular',
            uploadedAt: item.uploadedDate || 'Recently',
          };
        });
      } catch (e) {
        // Try next instance
      }
    }

    // Invidious fallback for search
    for (const instance of this.INVIDIOUS_INSTANCES) {
      try {
        const url = `${instance}/api/v1/search?q=${encodeURIComponent(query)}&type=video`;
        const response = await fetch(url);
        if (!response.ok) continue;

        const items = (await response.json()) as any[];
        if (!Array.isArray(items) || items.length === 0) continue;

        return items.slice(0, limit).map((item: any) => ({
          id: `youtube:${item.videoId}`,
          title: item.title || 'Unknown Title',
          uploader: item.author || 'YouTube Creator',
          duration: item.lengthSeconds || 0,
          thumbnail: item.videoThumbnails?.slice(-1)[0]?.url || `https://i.ytimg.com/vi/${item.videoId}/hqdefault.jpg`,
          views: item.viewCount ? `${(item.viewCount / 1000).toFixed(1)}k views` : 'Popular',
          uploadedAt: item.publishedText || 'Recently',
        }));
      } catch (e) {
        // Try next
      }
    }

    return [];
  }

  /**
   * Get Trending Music & Video Items
   */
  static async getTrendingVideos(limit = 20): Promise<VideoItem[]> {
    for (const instance of this.PIPED_INSTANCES) {
      try {
        const url = `${instance}/trending?region=US`;
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) continue;

        const items = (await response.json()) as any[];
        if (!Array.isArray(items) || items.length === 0) continue;

        return items.slice(0, limit).map((item: any) => {
          const videoId = item.url ? item.url.split('v=')[1] : '';
          return {
            id: `youtube:${videoId}`,
            title: item.title || 'Trending Video',
            uploader: item.uploaderName || 'YouTube Creator',
            duration: item.duration || 0,
            thumbnail: item.thumbnail || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
            views: item.views ? `${(item.views / 1000).toFixed(1)}k views` : 'Trending',
            uploadedAt: item.uploadedDate || 'Today',
          };
        });
      } catch (e) {
        // Try next instance
      }
    }

    return [];
  }

  /**
   * Direct InnerTube search
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
   * Resolves direct streamable Opus / AAC audio URL
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

  /**
   * Resolves MP4 Video Streams (1080p, 720p, 480p, 360p) with Age Restriction Bypass
   */
  static async getVideoStreams(videoId: string): Promise<{ title: string; streams: VideoStreamItem[]; audioUrl?: string }> {
    const cleanId = videoId.includes(':') ? videoId.split(':')[1] : videoId;

    // 1. Invidious API (Very reliable for video MP4 streams)
    for (const instance of this.INVIDIOUS_INSTANCES) {
      try {
        const url = `${instance}/api/v1/videos/${cleanId}`;
        const response = await fetch(url);
        if (!response.ok) continue;

        const data = (await response.json()) as any;
        const formatStreams = data.formatStreams || [];

        const streams: VideoStreamItem[] = formatStreams.map((fs: any) => ({
          quality: fs.qualityLabel || `${fs.height}p` || '720p',
          url: fs.url,
          mimeType: fs.container ? `video/${fs.container}` : 'video/mp4',
          hasAudio: true,
        }));

        if (streams.length > 0) {
          return {
            title: data.title || 'Music Video',
            streams,
          };
        }
      } catch (e) {
        // Try next Invidious instance
      }
    }

    // 2. Piped API Video Extractor
    for (const instance of this.PIPED_INSTANCES) {
      try {
        const url = `${instance}/streams/${cleanId}`;
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) continue;

        const data = (await response.json()) as any;
        const videoStreams = data.videoStreams || [];
        const audioStreams = data.audioStreams || [];

        let bestAudioUrl = '';
        if (audioStreams.length > 0) {
          audioStreams.sort((a: any, b: any) => (b.bitrate || 0) - (a.bitrate || 0));
          bestAudioUrl = audioStreams[0].url || '';
        }

        const streams: VideoStreamItem[] = videoStreams.map((vs: any) => ({
          quality: vs.quality || '720p',
          url: vs.url,
          mimeType: vs.mimeType || 'video/mp4',
          hasAudio: vs.videoOnly === false,
        }));

        if (streams.length > 0) {
          return {
            title: data.title || 'Music Video',
            streams,
            audioUrl: bestAudioUrl,
          };
        }
      } catch (e) {
        // Try next Piped instance on failure
      }
    }

    // 3. TVHTML5_SIMPLY_EMBEDDED_PLAYER InnerTube (Age Restriction Bypass)
    try {
      const url = `https://www.youtube.com/youtubei/v1/player`;
      const body = {
        context: {
          client: {
            clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
            clientVersion: '2.0',
            hl: 'en',
            gl: 'US',
          },
        },
        videoId: cleanId,
      };

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      if (response.ok) {
        const data = (await response.json()) as any;
        const formats = data.streamingData?.formats || [];
        const adaptiveFormats = data.streamingData?.adaptiveFormats || [];
        const allFormats = [...formats, ...adaptiveFormats];

        const streams: VideoStreamItem[] = [];
        for (const fmt of allFormats) {
          if (fmt.url && fmt.mimeType?.includes('video')) {
            streams.push({
              quality: fmt.qualityLabel || `${fmt.height || 720}p`,
              url: fmt.url,
              mimeType: fmt.mimeType,
              hasAudio: !fmt.mimeType.includes('audio'),
            });
          }
        }

        if (streams.length > 0) {
          return {
            title: data.videoDetails?.title || 'Music Video',
            streams,
          };
        }
      }
    } catch (e) {
      console.error('InnerTube TVHTML5 video stream resolution failed:', e);
    }

    return { title: 'Music Video', streams: [] };
  }
}
