export interface NativeSong {
  id: string;
  title: string;
  artist: string;
  album: string;
  duration: number;
  coverArt: string;
  streamUrl: string;
  hasLyrics?: boolean;
  language?: string;
  year?: number;
  explicit?: boolean;
  createdAt: string;
}

export interface NativePlaylist {
  id: string;
  title: string;
  description: string;
  coverArt: string;
  trackCount: number;
  tracks: NativeSong[];
}

export class NativeDatabaseProvider {
  /**
   * Default initial seed dataset for your custom Native API catalog
   */
  private static initialCatalog: NativeSong[] = [
    {
      id: 'native:song_1',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      duration: 200,
      coverArt: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      hasLyrics: true,
      language: 'English',
      year: 2020,
      explicit: false,
      createdAt: new Date().toISOString(),
    },
    {
      id: 'native:song_2',
      title: 'Starboy',
      artist: 'The Weeknd',
      album: 'Starboy',
      duration: 230,
      coverArt: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      hasLyrics: true,
      language: 'English',
      year: 2016,
      explicit: true,
      createdAt: new Date().toISOString(),
    },
  ];

  /**
   * Fetch custom catalog from KV store or fallback to default dataset
   */
  static async getCatalog(kv: KVNamespace): Promise<NativeSong[]> {
    const cached = await kv.get('native:catalog', 'json');
    if (cached && Array.isArray(cached)) {
      return cached as NativeSong[];
    }
    await kv.put('native:catalog', JSON.stringify(this.initialCatalog));
    return this.initialCatalog;
  }

  /**
   * Insert a new song into your native database
   */
  static async addSong(kv: KVNamespace, song: Omit<NativeSong, 'id' | 'createdAt'> & { id?: string }): Promise<NativeSong> {
    const catalog = await this.getCatalog(kv);
    const newSong: NativeSong = {
      ...song,
      id: song.id || `native:song_${Date.now()}`,
      createdAt: new Date().toISOString(),
    };

    // Prevent duplicate IDs
    const existingIndex = catalog.findIndex((s) => s.id === newSong.id);
    if (existingIndex >= 0) {
      catalog[existingIndex] = newSong;
    } else {
      catalog.unshift(newSong);
    }

    await kv.put('native:catalog', JSON.stringify(catalog));
    return newSong;
  }

  /**
   * Search native catalog by query string
   */

  /**
   * Bulk insert a list of songs into your native database (Deduplicated)
   */
  static async addSongsBatch(kv: KVNamespace, newSongs: Array<Omit<NativeSong, 'id' | 'createdAt'> & { id?: string }>): Promise<{ addedCount: number; totalCount: number }> {
    const catalog = await this.getCatalog(kv);
    let addedCount = 0;

    for (const song of newSongs) {
      const targetId = song.id || `native:song_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`;
      const existingIndex = catalog.findIndex((s) => s.id === targetId || (s.title.toLowerCase() === song.title.toLowerCase() && s.artist.toLowerCase() === song.artist.toLowerCase()));
      
      const nativeItem: NativeSong = {
        ...song,
        id: targetId,
        createdAt: new Date().toISOString(),
      };

      if (existingIndex >= 0) {
        catalog[existingIndex] = nativeItem;
      } else {
        catalog.unshift(nativeItem);
        addedCount++;
      }
    }

    await kv.put('native:catalog', JSON.stringify(catalog));
    return { addedCount, totalCount: catalog.length };
  }

  static async searchSongs(kv: KVNamespace, query: string): Promise<NativeSong[]> {
    const catalog = await this.getCatalog(kv);
    const q = query.toLowerCase().trim();
    if (!q) return catalog;

    return catalog.filter(
      (s) =>
        s.title.toLowerCase().includes(q) ||
        s.artist.toLowerCase().includes(q) ||
        s.album.toLowerCase().includes(q)
    );
  }

  /**
   * Fetch home feed (featured playlists, trending, new releases)
   */
  static async getHomeFeed(kv: KVNamespace): Promise<any> {
    const catalog = await this.getCatalog(kv);
    const playlists: NativePlaylist[] = [
      {
        id: 'native:playlist_top_hits',
        title: 'Native Top Hits',
        description: 'The hottest tracks on your custom IT Feels API server',
        coverArt: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
        trackCount: catalog.length,
        tracks: catalog,
      },
    ];

    return {
      success: true,
      apiOwner: 'IT Feels Custom API Server',
      featuredPlaylists: playlists,
      trendingSongs: catalog.slice(0, 10),
      recentImports: catalog.slice(0, 5),
    };
  }
}
