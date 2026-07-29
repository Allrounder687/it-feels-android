import CryptoJS from 'crypto-js';

const DES_KEY = CryptoJS.enc.Utf8.parse('383465913834659138346591');
const SAAVN_BASE_URL = 'https://www.jiosaavn.com/api.php';

export interface NormalizedTrack {
  id: string;
  provider: 'saavn' | 'youtube' | 'spotify';
  title: string;
  artist: string;
  album: string;
  duration: number;
  coverArt: string;
  encryptedMediaUrl?: string;
  streamUrl?: string;
  hasLyrics: boolean;
  language: string;
  year: number;
  explicit: boolean;
}

export class SaavnProvider {
  /**
   * Decrypt JioSaavn encrypted_media_url into direct 320kbps audio CDN link
   */
  static decryptUrl(encryptedUrl: string): string {
    try {
      if (!encryptedUrl || !encryptedUrl.trim()) return '';
      const decrypted = CryptoJS.TripleDES.decrypt(encryptedUrl.trim(), DES_KEY, {
        mode: CryptoJS.mode.ECB,
        padding: CryptoJS.pad.Pkcs7,
      });
      const url = decrypted.toString(CryptoJS.enc.Utf8);
      if (!url) return '';
      let cleanUrl = url.replace('http://', 'https://');
      if (cleanUrl.includes('preview.saavncdn.com')) {
        cleanUrl = cleanUrl.replace('preview.saavncdn.com', 'aac.saavncdn.com');
      }
      if (cleanUrl.includes('_96.mp4')) {
        cleanUrl = cleanUrl.replace('_96.mp4', '_320.mp4');
      } else if (cleanUrl.includes('_160.mp4')) {
        cleanUrl = cleanUrl.replace('_160.mp4', '_320.mp4');
      }
      return cleanUrl;
    } catch (e) {
      console.error('Failed to decrypt Saavn URL:', e);
      return '';
    }
  }

  /**
   * Search songs via JioSaavn API
   */
  static async search(query: string, page = 1, limit = 20): Promise<NormalizedTrack[]> {
    const params = new URLSearchParams({
      __call: 'search.getResults',
      p: page.toString(),
      n: limit.toString(),
      q: query,
      _format: 'json',
      _marker: '0',
      api_version: '4',
    });

    const response = await fetch(`${SAAVN_BASE_URL}?${params.toString()}`);
    const data = (await response.json()) as any;
    const results = data?.results || [];

    return results.map((item: any) => this.normalizeTrack(item));
  }

  /**
   * Fetch song details by Saavn ID or URL
   */
  static async getDetails(saavnId: string): Promise<NormalizedTrack | null> {
    const params = new URLSearchParams({
      __call: 'song.getDetails',
      pids: saavnId,
      _format: 'json',
      _marker: '0',
      api_version: '4',
    });

    const response = await fetch(`${SAAVN_BASE_URL}?${params.toString()}`);
    const data = (await response.json()) as any;
    const songObj = data?.[saavnId] || data?.songs?.[0];
    return songObj ? this.normalizeTrack(songObj) : null;
  }

  private static normalizeTrack(item: any): NormalizedTrack {
    const id = item.id || item.song_id || '';
    const title = item.title || item.song || item.name || 'Unknown Title';
    
    // Parse artists
    let artist = 'Unknown Artist';
    if (item.more_info?.artistMap?.primary_artists?.length > 0) {
      artist = item.more_info.artistMap.primary_artists.map((a: any) => a.name).join(', ');
    } else if (item.artist) {
      artist = item.artist;
    } else if (item.more_info?.singers) {
      artist = item.more_info.singers;
    }

    const album = item.album || item.more_info?.album || '';
    const duration = parseInt(item.duration || item.more_info?.duration || '0', 10);
    
    // Process cover art resolution
    let coverArt = item.image || item.more_info?.image || '';
    if (coverArt) {
      coverArt = coverArt.replace('150x150', '500x500').replace('50x50', '500x500');
    }

    const encUrl = item.encrypted_media_url || 
                   item.more_info?.encrypted_media_url || 
                   item.encrypted_url || 
                   item.more_info?.encrypted_url || 
                   item.media_url || 
                   item.more_info?.media_url || 
                   '';
    const streamUrl = encUrl ? this.decryptUrl(encUrl) : (item.media_preview_url || '');
    const hasLyrics = item.more_info?.has_lyrics === 'true' || item.more_info?.has_lyrics === true;

    return {
      id: `saavn:${id}`,
      provider: 'saavn',
      title: title.replace(/&quot;/g, '"').replace(/&amp;/g, '&'),
      artist: artist.replace(/&quot;/g, '"').replace(/&amp;/g, '&'),
      album: album.replace(/&quot;/g, '"').replace(/&amp;/g, '&'),
      duration,
      coverArt,
      encryptedMediaUrl: encUrl,
      streamUrl,
      hasLyrics,
      language: item.language || item.more_info?.language || 'unknown',
      year: parseInt(item.year || item.more_info?.year || '2024', 10),
      explicit: item.explicit_content === '1' || item.explicit_content === 1,
    };
  }
}
