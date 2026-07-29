import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { SaavnProvider } from './providers/saavn';
import { LrcLibProvider } from './providers/lrclib';

const app = new Hono();

// Enable CORS for mobile app access
app.use('*', cors());

// Health Check
app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    service: 'IT Feels Proxy Engine',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Sources Directory (Dynamic source manifest compatibility)
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
      source_id: 'in.itfeels.provider.lrclib',
      source_name: 'LrcLibLyricsProvider',
      source_type: 'PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.youtube',
      source_name: 'YoutubeProvider',
      source_type: 'DOWNLOADABLE_PROVIDER',
      version: '1.0.0',
      enabledByDefault: false,
    },
  ]);
});

// Multi-Source Search Route
app.get('/api/v1/search', async (c) => {
  const query = c.req.query('query');
  const page = parseInt(c.req.query('page') || '1', 10);
  const limit = parseInt(c.req.query('limit') || '20', 10);
  const provider = c.req.query('provider') || 'saavn';

  if (!query) {
    return c.json({ error: 'Query parameter is required' }, 400);
  }

  try {
    if (provider === 'saavn' || provider === 'all') {
      const results = await SaavnProvider.search(query, page, limit);
      return c.json({
        success: true,
        query,
        provider: 'saavn',
        results,
      });
    }

    return c.json({ error: `Provider '${provider}' not supported yet` }, 400);
  } catch (e: any) {
    return c.json({ error: 'Search failed', details: e.message }, 500);
  }
});

// Stream URL Resolution Route
app.get('/api/v1/stream', async (c) => {
  const id = c.req.query('id');
  const encUrl = c.req.query('encryptedUrl');

  if (!id && !encUrl) {
    return c.json({ error: 'Either song id or encryptedUrl is required' }, 400);
  }

  try {
    if (encUrl) {
      const streamUrl = SaavnProvider.decryptUrl(encUrl);
      return c.json({ success: true, streamUrl });
    }

    if (id) {
      const cleanId = id.includes(':') ? id.split(':')[1] : id;
      const songDetails = await SaavnProvider.getDetails(cleanId);

      if (songDetails && songDetails.streamUrl) {
        return c.json({
          success: true,
          id,
          streamUrl: songDetails.streamUrl,
          bitrate: '320kbps',
        });
      }
    }

    return c.json({ error: 'Stream URL could not be resolved' }, 404);
  } catch (e: any) {
    return c.json({ error: 'Stream resolution failed', details: e.message }, 500);
  }
});

// Synced & Plain Lyrics Route
app.get('/api/v1/lyrics', async (c) => {
  const track = c.req.query('track');
  const artist = c.req.query('artist');
  const album = c.req.query('album');
  const duration = parseInt(c.req.query('duration') || '0', 10);

  if (!track || !artist) {
    return c.json({ error: 'track and artist parameters are required' }, 400);
  }

  try {
    const lyrics = await LrcLibProvider.getLyrics(track, artist, album, duration);
    if (!lyrics) {
      return c.json({ success: false, message: 'Lyrics not found' }, 404);
    }
    return c.json({ success: true, lyrics });
  } catch (e: any) {
    return c.json({ error: 'Lyrics fetch failed', details: e.message }, 500);
  }
});

export default app;
