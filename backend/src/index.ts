import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { SaavnProvider } from './providers/saavn';
import { YoutubeProvider } from './providers/youtube';
import { SpotifyProvider } from './providers/spotify';
import { LrcLibProvider } from './providers/lrclib';
import { MusixmatchProvider } from './providers/musixmatch';

const app = new Hono();

// Enable CORS for mobile app access
app.use('*', cors());

// Health Check
app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    service: 'FEELS Cloud Proxy Engine',
    version: '1.1.0',
    providers: ['saavn', 'youtube', 'spotify', 'lrclib', 'musixmatch'],
    timestamp: new Date().toISOString(),
  });
});

// Sources Directory (Dynamic source manifest registry)
app.get('/api/v1/sources', (c) => {
  return c.json([
    {
      source_id: 'in.itfeels.provider.saavn',
      source_name: 'SaavnProvider',
      source_type: 'DOWNLOADABLE_PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.youtube',
      source_name: 'YoutubeProvider',
      source_type: 'DOWNLOADABLE_PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.spotify',
      source_name: 'SpotifyProvider',
      source_type: 'QUERYABLE_PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
      extraDeps: [
        {
          source_id: 'in.itfeels.provider.saavn',
          source_type: 'DOWNLOADABLE_PROVIDER',
        },
        {
          source_id: 'in.itfeels.provider.youtube',
          source_type: 'DOWNLOADABLE_PROVIDER',
        },
      ],
    },
    {
      source_id: 'in.itfeels.provider.lrclib',
      source_name: 'LrcLibLyricsProvider',
      source_type: 'PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.musixmatch',
      source_name: 'MusixmatchLyricsProvider',
      source_type: 'PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
  ]);
});

// Multi-Source Search Route
app.get('/api/v1/search', async (c) => {
  const query = c.req.query('query');
  const page = parseInt(c.req.query('page') || '1', 10);
  const limit = parseInt(c.req.query('limit') || '20', 10);
  const provider = c.req.query('provider') || 'all';

  if (!query) {
    return c.json({ error: 'Query parameter is required' }, 400);
  }

  try {
    if (provider === 'saavn') {
      const results = await SaavnProvider.search(query, page, limit);
      return c.json({ success: true, query, provider: 'saavn', results });
    }

    if (provider === 'youtube') {
      const results = await YoutubeProvider.search(query, limit);
      return c.json({ success: true, query, provider: 'youtube', results });
    }

    if (provider === 'spotify') {
      const results = await SpotifyProvider.search(query, limit);
      return c.json({ success: true, query, provider: 'spotify', results });
    }

    // Default: 'all' -> Query Saavn, YouTube, and Spotify in parallel
    const [saavnRes, ytRes, spotifyRes] = await Promise.allSettled([
      SaavnProvider.search(query, page, limit),
      YoutubeProvider.search(query, limit),
      SpotifyProvider.search(query, limit),
    ]);

    const saavnList = saavnRes.status === 'fulfilled' ? saavnRes.value : [];
    const ytList = ytRes.status === 'fulfilled' ? ytRes.value : [];
    const spotifyList = spotifyRes.status === 'fulfilled' ? spotifyRes.value : [];

    const combined = [...saavnList, ...ytList, ...spotifyList];

    return c.json({
      success: true,
      query,
      provider: 'all',
      totalCount: combined.length,
      results: combined,
    });
  } catch (e: any) {
    return c.json({ error: 'Search failed', details: e.message }, 500);
  }
});

// Stream URL Resolution Route
app.get('/api/v1/stream', async (c) => {
  const id = c.req.query('id');
  const encUrl = c.req.query('encryptedUrl');
  const title = c.req.query('title');
  const artist = c.req.query('artist');

  if (!id && !encUrl && (!title || !artist)) {
    return c.json({ error: 'Either id, encryptedUrl, or title+artist is required' }, 400);
  }

  try {
    // 1. Direct JioSaavn encrypted URL decryption
    if (encUrl && encUrl.trim()) {
      const streamUrl = SaavnProvider.decryptUrl(encUrl);
      if (streamUrl) {
        return c.json({ success: true, provider: 'saavn', streamUrl });
      }
    }

    // 2. ID-based resolution (handles saavn:123, youtube:xyz, or raw ID)
    if (id) {
      const cleanId = id.includes(':') ? id.split(':')[1] : id;

      if (id.startsWith('youtube:')) {
        const streamUrl = await YoutubeProvider.getAudioStream(cleanId);
        if (streamUrl) {
          return c.json({ success: true, provider: 'youtube', id, streamUrl, bitrate: '160kbps' });
        }
      } else if (id.startsWith('spotify:') && title && artist) {
        const streamUrl = await SpotifyProvider.getAudioStream(title, artist);
        if (streamUrl) {
          return c.json({ success: true, provider: 'spotify', id, streamUrl });
        }
      } else {
        // Default: JioSaavn ID lookup (cleanId)
        const songDetails = await SaavnProvider.getDetails(cleanId);
        if (songDetails?.streamUrl) {
          return c.json({ success: true, provider: 'saavn', id, streamUrl: songDetails.streamUrl, bitrate: '320kbps' });
        }
      }
    }

    // 3. Title + Artist fallback matching
    if (title && artist) {
      const streamUrl = await SpotifyProvider.getAudioStream(title, artist);
      if (streamUrl) {
        return c.json({ success: true, provider: 'chain', streamUrl });
      }
    }

    return c.json({ error: 'Stream URL could not be resolved' }, 404);
  } catch (e: any) {
    return c.json({ error: 'Stream resolution failed', details: e.message }, 500);
  }
});

// Synced & Plain Lyrics Route (LrcLib -> Musixmatch Waterfall)
app.get('/api/v1/lyrics', async (c) => {
  const track = c.req.query('track');
  const artist = c.req.query('artist');
  const album = c.req.query('album');
  const duration = parseInt(c.req.query('duration') || '0', 10);

  if (!track || !artist) {
    return c.json({ error: 'track and artist parameters are required' }, 400);
  }

  try {
    // 1. Try LrcLib primary
    let lyrics = await LrcLibProvider.getLyrics(track, artist, album, duration);
    
    // 2. Fallback to Musixmatch
    if (!lyrics || (!lyrics.syncedLyrics && !lyrics.plainLyrics)) {
      const mxmResult = await MusixmatchProvider.getLyrics(track, artist, album);
      if (mxmResult) lyrics = mxmResult;
    }

    if (!lyrics) {
      return c.json({ success: false, message: 'Lyrics not found' }, 404);
    }

    return c.json({ success: true, lyrics });
  } catch (e: any) {
    return c.json({ error: 'Lyrics fetch failed', details: e.message }, 500);
  }
});

export default app;
