import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { SaavnProvider } from './providers/saavn';
import { YoutubeProvider } from './providers/youtube';
import { SpotifyProvider } from './providers/spotify';
import { LrcLibProvider } from './providers/lrclib';
import { MusixmatchProvider } from './providers/musixmatch';

type Bindings = {
  SEARCH_CACHE: KVNamespace;
  API_SECRET: string;
  OPENAI_API_KEY?: string;
  ANTHROPIC_API_KEY?: string;
  GEMINI_API_KEY?: string;
  RESEND_API_KEY?: string;
  RAZORPAY_KEY_ID?: string;
  RAZORPAY_KEY_SECRET?: string;
};

const app = new Hono<{ Bindings: Bindings }>();

// Enable CORS for mobile app access
app.use('*', cors());

// API Security Middleware
app.use('/api/*', async (c, next) => {
  const secret = c.req.header('X-Feels-Secret');
  if (c.env.API_SECRET && secret !== c.env.API_SECRET) {
    return c.json({ error: 'Unauthorized', message: 'Invalid or missing API secret' }, 401);
  }
  await next();
});

// Health Check
app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    service: 'FEELS Cloud Proxy Engine',
    version: '1.2.0',
    providers: ['saavn', 'youtube', 'spotify', 'lrclib', 'musixmatch'],
    videoSupport: true,
    ageRestrictionBypass: true,
    timestamp: new Date().toISOString(),
  });
});

// Email Service (Resend)
app.post('/api/v1/send-email', async (c) => {
  try {
    if (!c.env.RESEND_API_KEY) {
      return c.json({ error: 'Configuration Error', message: 'RESEND_API_KEY is not configured on the server.' }, 500);
    }

    const body = await c.req.json();
    const { to, subject, html } = body;

    if (!to || !subject || !html) {
      return c.json({ error: 'Bad Request', message: 'Missing required fields: to, subject, or html' }, 400);
    }

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${c.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: 'IT Feels Music <hello@it-feels.com>',
        to: [to],
        subject: subject,
        html: html
      })
    });

    const data = await response.json();
    if (!response.ok) {
      return c.json({ error: 'Email Failed', details: data }, response.status);
    }

    return c.json({ success: true, id: data.id });
  } catch (error: any) {
    return c.json({ error: 'Internal Server Error', message: error.message }, 500);
  }
});

// Razorpay Order Generation
app.post('/api/v1/razorpay/order', async (c) => {
  try {
    if (!c.env.RAZORPAY_KEY_ID || !c.env.RAZORPAY_KEY_SECRET) {
      return c.json({ error: 'Configuration Error', message: 'Razorpay keys not configured' }, 500);
    }

    const body = await c.req.json();
    const { amount, currency = 'INR', receipt } = body;

    if (!amount) {
      return c.json({ error: 'Bad Request', message: 'Amount is required (in paise)' }, 400);
    }

    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + btoa(`${c.env.RAZORPAY_KEY_ID}:${c.env.RAZORPAY_KEY_SECRET}`)
      },
      body: JSON.stringify({
        amount,
        currency,
        receipt: receipt || `rcpt_${Date.now()}`
      })
    });

    const data = await response.json();
    if (!response.ok) {
      return c.json({ error: 'Razorpay Error', details: data }, response.status);
    }

    return c.json(data);
  } catch (error: any) {
    return c.json({ error: 'Internal Server Error', message: error.message }, 500);
  }
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
      version: '1.2.0',
      videoSupported: true,
      ageBypass: true,
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

  const cacheKey = `search:${provider}:${query}:${page}:${limit}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) {
    return c.json(cached);
  }

  try {
    if (provider === 'saavn') {
      const results = await SaavnProvider.search(query, page, limit);
      const res = { success: true, query, provider: 'saavn', results };
      c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
      return c.json(res);
    }

    if (provider === 'youtube') {
      const results = await YoutubeProvider.search(query, limit);
      const res = { success: true, query, provider: 'youtube', results };
      c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
      return c.json(res);
    }

    if (provider === 'spotify') {
      const results = await SpotifyProvider.search(query, limit);
      const res = { success: true, query, provider: 'spotify', results };
      c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
      return c.json(res);
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

    const res = {
      success: true,
      query,
      provider: 'all',
      totalCount: combined.length,
      results: combined,
    };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Search failed', details: e.message }, 500);
  }
});

// Video Stream Resolution Route (with Age Restriction Bypass)
app.get('/api/v1/video', async (c) => {
  const id = c.req.query('id');
  const query = c.req.query('query');

  if (!id && !query) {
    return c.json({ error: 'Either id or query parameter is required' }, 400);
  }

  try {
    let videoId = id || '';
    if (query && !videoId) {
      const searchRes = await YoutubeProvider.searchVideos(query, 1);
      if (searchRes.length > 0) {
        videoId = searchRes[0].id;
      }
    }

    if (!videoId) {
      return c.json({ error: 'Video not found' }, 404);
    }

    const videoData = await YoutubeProvider.getVideoStreams(videoId);
    return c.json({
      success: true,
      id: videoId,
      title: videoData.title,
      streams: videoData.streams,
      audioUrl: videoData.audioUrl || '',
    });
  } catch (e: any) {
    return c.json({ error: 'Video stream resolution failed', details: e.message }, 500);
  }
});

// Video Search Route for Dedicated Videos Tab
app.get('/api/v1/videos/search', async (c) => {
  const query = c.req.query('query');
  const limit = parseInt(c.req.query('limit') || '20', 10);

  if (!query) {
    return c.json({ error: 'Query parameter is required' }, 400);
  }

  try {
    const videos = await YoutubeProvider.searchVideos(query, limit);
    return c.json({ success: true, query, totalCount: videos.length, videos });
  } catch (e: any) {
    return c.json({ error: 'Video search failed', details: e.message }, 500);
  }
});

// Trending Videos Route for Dedicated Videos Tab
app.get('/api/v1/videos/trending', async (c) => {
  const limit = parseInt(c.req.query('limit') || '20', 10);

  try {
    const videos = await YoutubeProvider.getTrendingVideos(limit);
    return c.json({ success: true, totalCount: videos.length, videos });
  } catch (e: any) {
    return c.json({ error: 'Trending videos fetch failed', details: e.message }, 500);
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

  const cacheKey = `lyrics:${track}:${artist}:${album || ''}:${duration}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) {
    return c.json(cached);
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

    const res = { success: true, lyrics };
    // Cache lyrics for 7 days
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 604800 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Lyrics fetch failed', details: e.message }, 500);
  }
});

// Image Proxy Route (Caches images at the edge via Cloudflare CDN)
app.get('/api/v1/image-proxy', async (c) => {
  const url = c.req.query('url');
  
  if (!url) {
    return c.json({ error: 'url parameter is required' }, 400);
  }

  try {
    const imageRes = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    });

    if (!imageRes.ok) {
      return c.json({ error: 'Failed to fetch image' }, imageRes.status as any);
    }

    // Set aggressive cache headers to cache the binary data at the edge
    c.header('Cache-Control', 'public, max-age=31536000, immutable');
    c.header('Content-Type', imageRes.headers.get('Content-Type') || 'image/jpeg');

    return c.body(imageRes.body);
  } catch (e: any) {
    return c.json({ error: 'Image proxy failed', details: e.message }, 500);
  }
});

// AI Proxy Route
app.post('/api/v1/ai/action', async (c) => {
  const body = await c.req.json().catch(() => ({} as any));
  const { provider, action, payload } = body;
  
  if (!provider || !action || !payload) {
    return c.json({ error: 'Missing provider, action, or payload' }, 400);
  }

  try {
    const { handleOpenAIAction, handleClaudeAction, handleGeminiAction } = await import('./ai');
    let result: any = null;
    
    if (provider === 'chatgpt') {
      const apiKey = c.env.OPENAI_API_KEY;
      if (!apiKey) throw new Error('OPENAI_API_KEY missing');
      result = await handleOpenAIAction(apiKey, action, payload);
    } else if (provider === 'claude') {
      const apiKey = c.env.ANTHROPIC_API_KEY;
      if (!apiKey) throw new Error('ANTHROPIC_API_KEY missing');
      result = await handleClaudeAction(apiKey, action, payload);
    } else if (provider === 'gemini') {
      const apiKey = c.env.GEMINI_API_KEY;
      if (!apiKey) throw new Error('GEMINI_API_KEY missing');
      result = await handleGeminiAction(apiKey, action, payload);
    } else {
      throw new Error('Unsupported provider');
    }
    
    return c.json({ success: true, result });
  } catch (e: any) {
    return c.json({ success: false, error: e.message }, 500);
  }
});

// Welcome Email Route (via Resend)
app.post('/api/v1/email/welcome', async (c) => {
  const body = await c.req.json().catch(() => ({} as any));
  const { email } = body;
  
  if (!email) {
    return c.json({ error: 'Missing email address' }, 400);
  }

  const apiKey = c.env.RESEND_API_KEY;
  if (!apiKey) {
    return c.json({ error: 'Resend API key not configured on server' }, 500);
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'IT Feels <noreply@itfeels.in>',
        to: email,
        subject: '🎧 You passed the vibe check. Welcome to IT Feels!',
        html: `
          <div style="font-family: sans-serif; color: #333; line-height: 1.6;">
            <h2>Hey there,</h2>
            <p>We see you. You've got good taste.</p>
            <p>Your account is officially locked in, which means your playlists are safe, your vibe is secure, and the cloud sync is ready to roll.</p>
            <p>Welcome to <strong>IT Feels</strong>. Turn the volume up.</p>
            <br/>
            <p>Keep it playing,<br/><strong>The IT Feels Team ✌️</strong></p>
          </div>
        `,
      }),
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(\`Resend API error: \${res.status} \${errorText}\`);
    }

    const data = await res.json();
    return c.json({ success: true, data });
  } catch (e: any) {
    return c.json({ success: false, error: e.message }, 500);
  }
});

// Telemetry Play Event Route
app.post('/api/v1/telemetry/play', async (c) => {
  const body = await c.req.json().catch(() => ({} as any));
  const { songId, title, artist, coverArt } = body;
  
  if (!songId) return c.json({ error: 'Missing songId' }, 400);

  const today = new Date().toISOString().split('T')[0];
  const chartKey = `chart:${today}`;

  c.executionCtx.waitUntil((async () => {
    let chart = await c.env.SEARCH_CACHE.get(chartKey, 'json') as any || {};
    if (!chart[songId]) {
      chart[songId] = { count: 0, title, artist, coverArt };
    }
    chart[songId].count += 1;
    await c.env.SEARCH_CACHE.put(chartKey, JSON.stringify(chart), { expirationTtl: 86400 * 7 });
  })());

  return c.json({ success: true });
});

// Telemetry Trending Charts Route
app.get('/api/v1/charts/trending', async (c) => {
  const today = new Date().toISOString().split('T')[0];
  const chartKey = `chart:${today}`;
  let chart = await c.env.SEARCH_CACHE.get(chartKey, 'json') as any || {};
  
  const trending = Object.entries(chart)
    .map(([id, data]: any) => ({ id, ...data }))
    .sort((a: any, b: any) => b.count - a.count)
    .slice(0, 50);

  return c.json({ success: true, trending });
});

export default app;
